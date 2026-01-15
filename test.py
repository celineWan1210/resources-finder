import requests

# Your Google API key
final String googleApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

# Kuala Lumpur coordinates
latitude = 3.1390
longitude = 101.6869

# Keywords we care about
keywords = ["food bank", "food charity", "lost food project", "food aid", "charity food"]
keywords_lower = [k.lower() for k in keywords]

# To store unique places
all_places = []

for keyword in keywords:
    print(f"\nSearching for: {keyword}")

    url = (
        "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
        f"?location={latitude},{longitude}"
        "&radius=10000"           # 5 km radius
        "&type=establishment"    # Only establishments
        f"&keyword={keyword.replace(' ', '+')}"
        f"&key={API_KEY}"
    )

    response = requests.get(url)

    if response.status_code == 200:
        data = response.json()
        results = data.get('results', [])

        if not results:
            print(f"No results found for '{keyword}'")
            continue

        for place in results:
            name = place.get('name', '').lower()
            address = place.get('vicinity', '')

            # Filter: include only if the name contains one of our keywords
            if any(k in name for k in keywords_lower):
                lat = place['geometry']['location']['lat']
                lng = place['geometry']['location']['lng']

                print(f"Name: {place['name']}")
                print(f"Address: {address}")
                print(f"Location: ({lat}, {lng})")
                print("-" * 40)

                # Add unique places only
                if place not in all_places:
                    all_places.append(place)
    else:
        print(f"Error {response.status_code} for keyword '{keyword}'")

print(f"\nTotal unique food-related places found: {len(all_places)}")
