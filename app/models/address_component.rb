class AddressComponent
  attr_reader :long_name, :short_name, :types

  def initialize(params)
    if params[:long_name]
      @long_name=params[:long_name]
    end
    if params[:short_name]
      @short_name=params[:short_name]
    end
    if params[:types]
      @types=params[:types]
    end
  end  
end
