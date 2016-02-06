class Photo
	include ActiveModel::Model

	attr_accessor :id, :location, :contents, :place

  # convenience method for access to client in console
  def self.mongo_client
    Mongoid::Clients.default
  end

	def initialize(params={})
    if params[:_id]
      @id=params[:_id].to_s
      @location=params[:metadata].nil? ? nil : Point.new(params[:metadata][:location])
      @place=params[:metadata].nil? ? nil : params[:metadata][:place]
    end
	end

	def persisted?
		!@id.nil?
	end

  def place 
    Place.find(@place) if !@place.nil?
  end

  def place=(p)
    if p.class == Place
      @place = BSON::ObjectId.from_string(p.id)
    elsif p.class == String
      @place=BSON::ObjectId.from_string(p)
    else
      @place = p
    end
  end

	def save
		# Rails.logger.debug {"saving photo file #{self.to_s}"}
		if !self.persisted?
			if @contents
				f = File.open(@contents.path, 'rb')
				@contents=f
				gps=EXIFR::JPEG.new(@contents).gps
				@location=Point.new(:lng=>gps.longitude,:lat=>gps.latitude)
				description = {}
				description[:content_type]='image/jpeg'
				description[:metadata]={}
				description[:metadata][:location]=@location.to_hash
        description[:metadata][:place]=@place.to_hash if !@place.nil?
				@contents.rewind
				grid_file = Mongo::Grid::File.new(@contents.read, description )
				id=self.class.mongo_client.database.fs.insert_one(grid_file)
				@id=id.to_s
			end
		else
			doc = self.class.mongo_client.database.fs.find(:_id=>BSON::ObjectId.from_string(@id)).first
			doc[:metadata][:location]=@location.to_hash
      doc[:metadata][:place]=@place
			self.class.mongo_client.database.fs.find(:_id=>BSON::ObjectId.from_string(@id)).update_one(doc)
			#	@id=id.to_s
			doc = self.class.mongo_client.database.fs.find(:_id=>BSON::ObjectId.from_string(@id)).first
		end
  end

  def self.all(offset=0, limit=nil)
    files=[]
    result=self.mongo_client.database.fs.find.skip(offset).each do |r|
      files << Photo.new(r) if limit.nil? or files.count < limit 
    end
    return files
  end

  def self.find(id)
    f=Photo.mongo_client.database.fs.find(:_id=>BSON::ObjectId.from_string(id)).first if !id.nil?
    photo=!f.nil? ? Photo.new(f) : nil
    return photo
  end

	def contents
    # Rails.logger.debug {"getting content #{@id}"}
    f=self.class.mongo_client.database.fs.find_one(:_id=>BSON::ObjectId.from_string(@id))
    if f 
      buffer = ""
      f.chunks.reduce([]) do |x,chunk| 
          buffer << chunk.data.data 
      end
      return buffer
    end 
  end

	def destroy
    # Rails.logger.debug {"destroying file #{@id}"}
		self.class.mongo_client.database.fs.find(_id:BSON::ObjectId.from_string(@id)).delete_one
  end

	def find_nearest_place_id(max_meters)
		place=Place.near(@location,max_meters).first
		return !place.nil? ? place[:_id] : nil
	end

  def self.find_photos_for_place(place_id)
    result=self.mongo_client.database.fs.find(:"metadata.place" => BSON::ObjectId.from_string(place_id))
  end
end
