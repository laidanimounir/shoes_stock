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
}
