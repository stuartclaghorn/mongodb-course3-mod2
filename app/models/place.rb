class Place
  include ActiveModel::Model

  attr_accessor :id, :formatted_address, :location, :address_components

  # convenience method for access to client in console
  def self.mongo_client
    Mongoid::Clients.default
  end

  # convenience method for access to places collection
  def self.collection
    self.mongo_client['places']
  end

  def persisted?
    !@id.nil?
  end

  # load json data into places collection
  def self.load_all(file_path)
    f=File.read(file_path)
    hash=JSON.parse(f)
    @coll=self.collection.insert_many(hash)
  end

  # initialize
  def initialize(params)
    # Rails.logger.debug(params)
    @id=params[:_id].nil? ? params[:id] : params[:_id].to_s
		if !params[:address_components].nil?
      @address_components=[]
			params[:address_components].each do |c|
				@address_components << AddressComponent.new(c) if !c.nil?
			end
		end
    @formatted_address=params[:formatted_address]
    @location=params[:geometry][:geolocation].nil? ? params[:geometry][:geolocation] : Point.new(params[:geometry][:geolocation])
  end

  # queries
  def self.find_by_short_name(name)
    @coll=self.collection.find({'address_components.short_name' => name})
  end

  def self.to_places(coll)
    result=[]
    coll.map { |d| result << Place.new(d) }
    return result
  end

  def self.find(id)
    result=self.collection.find({:_id => BSON::ObjectId.from_string(id)}).first
    return result.nil? ? nil : Place.new(result)
  end

  def self.all(offset=0, limit=nil)
    # Rails.logger.debug {"getting all places, offset=#{offset}, limit=#{limit}"}

    coll=collection.find().skip(offset)
    coll=coll.limit(limit) if !limit.nil?
    result=to_places(coll)
    return result
  end

  def destroy
    # Rails.logger.debug {"destroying #{self}"}
    self.class.collection.find(:_id => BSON::ObjectId.from_string(@id)).delete_one
  end

  def self.get_address_components(sort={:_id=>1}, offset=0, limit=9999)
    pipeline=[{:$project=>{'_id'=>1,"address_components"=>1,"formatted_address"=>1,"geometry.geolocation"=>1}},
               {:$unwind=>"$address_components"},
               {:$sort=>sort},
               {:$skip=>offset}]
    if !limit.nil? 
      pipeline<<{:$limit=>limit}
    end
    result=self.collection.find.aggregate(pipeline)
    return result
  end

	def self.get_country_names
		pipeline=[{:$project=>{'_id'=>1,"address_components.long_name"=>1,"address_components.types"=>1}},
						{:$unwind=>"$address_components"},
						{:$unwind=>"$address_components.types"},
						{:$match=>{:'address_components.types'=>'country'}},
						{:$group=>{:_id=>'$address_components.long_name'}}]
    coll=self.collection.find.aggregate(pipeline)
		result=coll.to_a.map {|h| h[:_id]}
		return result
	end

	def self.find_ids_by_country_code(country_code)
		pipeline=[{:$project=>{'_id'=>1,"address_components.short_name"=>1,"address_components.types"=>1, "geometry.geolocation"=>1}},
						{:$unwind=>"$address_components"},
						{:$unwind=>"$address_components.types"},
						{:$match=>{:'address_components.short_name'=>country_code,
							:'address_components.types'=>'country'}}]
    coll=self.collection.find.aggregate(pipeline)
		result=coll.to_a.map {|doc| doc[:_id].to_s}
		return result
	end

	def self.create_indexes
		self.collection.indexes.create_one({ :'geometry.geolocation' => Mongo::Index::GEO2DSPHERE})  
	end

	def self.remove_indexes
		self.collection.indexes.drop_one('geometry.geolocation_2dsphere')
	end

	def self.near(point, max_meters=0)
		self.collection.find('geometry.geolocation'=>{:$near=>{
				:$geometry=>point.to_hash,:$maxDistance=>max_meters}})
	end

	def near(max=0)
	 	places=[]
	 	self.class.near(@location, max).each {|p| places << Place.new(p)}
		return places
	end
  
  def photos(offset=0, limit=1000)
    photos=[]
    # a=result.to_a
    # h=Hash[*a]
    result=Photo.find_photos_for_place(@id).skip(offset).limit(limit)
    result.map { |v| photos << Photo.new(v) }
    return photos
  end
end
