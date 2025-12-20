class Contact {
  final String id;
  final String ownerUid;
  final String contactUid;
  final String contactEmail;
  final String contactName;
  final DateTime createdAt;
  final String? notes;

  Contact({
    required this.id,
    required this.ownerUid,
    required this.contactUid,
    required this.contactEmail,
    required this.contactName,
    required this.createdAt,
    this.notes,
  });

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
    id: json['id'] as String,
    ownerUid: json['owner_uid'] as String,
    contactUid: json['contact_uid'] as String,
    contactEmail: json['contact_email'] as String,
    contactName: json['contact_name'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    notes: json['notes'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_uid': ownerUid,
    'contact_uid': contactUid,
    'contact_email': contactEmail,
    'contact_name': contactName,
    'created_at': createdAt.toIso8601String(),
    if (notes != null) 'notes': notes,
  };

  String get displayName => contactName.isNotEmpty ? contactName : contactEmail;
  String get initial => contactName.isNotEmpty 
      ? contactName.substring(0, 1).toUpperCase() 
      : contactEmail.substring(0, 1).toUpperCase();
}