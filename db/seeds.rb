# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

require 'pp'
# Remove all GridFS Photos
Photo.all.each do |photo| 
  photo.destroy 
end

# Remove all places
Place.all.each do |place| 
  place.destroy 
end

# Create 2dsphere indexes for geometry.geolocation property in places
Place.create_indexes

# Load the provided json file
Place.load_all(File.open('./db/places.json'))

# Load the provided jpg images in the db directory
Dir.glob("./db/image*.jpg") do |f| 
  photo=Photo.new
  photo.contents=File.open(f,'rb')
  photo.save
end

# Associate each photo with a place
Photo.all.each do |photo| 
  place_id=photo.find_nearest_place_id 1*1609.34
  photo.place=place_id
  photo.save
end

# Pretty print results
pp Place.all.reject {|pl| pl.photos.empty?}.map {|pl| pl.formatted_address}.sort
