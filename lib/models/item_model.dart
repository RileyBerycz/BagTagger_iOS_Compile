class Item {
  String name;
  Map<String, String> descriptors;
  String? image;

  Item({
    required this.name, 
    this.descriptors = const {}, 
    this.image,
  });

  // For JSON serialization
  Map<String, dynamic> toJson() => {
    'name': name,
    'descriptors': descriptors,
    'image': image,
  };

  // From JSON deserialization
  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      name: json['name'] as String,
      descriptors: Map<String, String>.from(json['descriptors'] ?? {}),
      image: json['image'] as String?,
    );
  }

  // Clone method for editing
  Item clone() => Item(
    name: name,
    descriptors: Map<String, String>.from(descriptors),
    image: image,
  );
}