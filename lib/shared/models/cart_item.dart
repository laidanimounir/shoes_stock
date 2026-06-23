class CartItem {
  final String variantId;
  final String productName;
  final String size;
  final String color;
  int quantity;
  double unitPrice;

  CartItem({
    required this.variantId,
    required this.productName,
    required this.size,
    required this.color,
    required this.quantity,
    required this.unitPrice,
  });

  double get totalPrice => quantity * unitPrice;

  Map<String, dynamic> toMap() {
    return {
      'variantId': variantId,
      'productName': productName,
      'size': size,
      'color': color,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      variantId: map['variantId'] as String,
      productName: map['productName'] as String,
      size: map['size'] as String,
      color: map['color'] as String,
      quantity: map['quantity'] as int,
      unitPrice: (map['unitPrice'] as num).toDouble(),
    );
  }

  CartItem copyWith({
    String? variantId,
    String? productName,
    String? size,
    String? color,
    int? quantity,
    double? unitPrice,
  }) {
    return CartItem(
      variantId: variantId ?? this.variantId,
      productName: productName ?? this.productName,
      size: size ?? this.size,
      color: color ?? this.color,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }
}
