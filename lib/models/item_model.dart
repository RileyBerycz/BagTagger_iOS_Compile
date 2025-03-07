class Item {
  final String name;
  final Map<String, String> descriptors;
  final String? image;
  final String id;

  Item({
    required this.name, 
    required this.descriptors, 
    this.image,
    this.id = '',
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
    id: id,
  );
}