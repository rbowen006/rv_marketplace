SEEDS_DIR = Rails.root.join('db', 'seeds', 'images')

# Realistic Australian listing data to replace test placeholders
TEST_LISTING_UPDATES = {
  1  => { title: 'Sunshine Coast Surf Van',        location: 'Noosa Heads, QLD',    price_per_day: 149.00, max_guests: 2, pet_friendly: false },
  2  => { title: 'Blue Mountains Escape',          location: 'Katoomba, NSW',        price_per_day: 175.00, max_guests: 4, pet_friendly: true  },
  4  => { title: 'Byron Bay Retro Campervan',      location: 'Byron Bay, NSW',       price_per_day: 195.00, max_guests: 2, pet_friendly: true  },
  6  => { title: 'Alpine Adventure Van',           location: 'Thredbo, NSW',         price_per_day: 185.00, max_guests: 3, pet_friendly: false },
  8  => { title: 'Margaret River Weekend Retreat', location: 'Margaret River, WA',   price_per_day: 165.00, max_guests: 2, pet_friendly: true  },
  10 => { title: 'Great Ocean Road Classic',       location: 'Lorne, VIC',           price_per_day: 210.00, max_guests: 2, pet_friendly: false },
  12 => { title: 'Kakadu Family Motorhome',        location: 'Darwin, NT',           price_per_day: 220.00, max_guests: 6, pet_friendly: false },
}.freeze

IMAGE_ASSIGNMENTS = {
  1  => '8231107.jpg',
  2  => '14924831.jpg',
  4  => '5836331.jpg',
  6  => '6945637.jpg',
  8  => '9143451.jpg',
  10 => '210010.jpg',
  12 => '14523224.jpg',
  13 => '5809280.jpg',
}.freeze

puts "\n== Updating listing metadata =="
TEST_LISTING_UPDATES.each do |id, attrs|
  listing = RvListing.find_by(id: id)
  unless listing
    puts "  skip #{id} (not found)"
    next
  end
  listing.update!(attrs)
  puts "  ✓ #{id}: #{attrs[:title]}"
end

puts "\n== Attaching images =="
IMAGE_ASSIGNMENTS.each do |id, filename|
  listing = RvListing.find_by(id: id)
  unless listing
    puts "  skip #{id} (not found)"
    next
  end

  image_path = SEEDS_DIR.join(filename)
  unless image_path.exist?
    puts "  skip #{id}: #{filename} not found"
    next
  end

  listing.images.purge
  listing.images.attach(io: File.open(image_path), filename: filename, content_type: 'image/jpeg')
  puts "  ✓ #{id}: #{listing.title} ← #{filename}"
end

puts "\nDone."
