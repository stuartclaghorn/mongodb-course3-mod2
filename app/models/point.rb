class Point
  attr_accessor :longitude, :latitude

  def to_hash
    geom={:type=>"Point",:coordinates=>[@longitude,@latitude]}
  end

  def initialize(params)
    if params[:lat]
      @latitude=params[:lat] 
      @longitude=params[:lng]
    elsif params[:coordinates]
      @latitude=params[:coordinates][1]
      @longitude=params[:coordinates][0]
    end
  end
end
