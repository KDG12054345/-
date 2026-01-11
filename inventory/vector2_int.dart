class Vector2Int {
  final int x;
  final int y;
  
  const Vector2Int(this.x, this.y);
  
  Vector2Int operator +(Vector2Int other) => 
    Vector2Int(x + other.x, y + other.y);
  
  Vector2Int operator -(Vector2Int other) => 
    Vector2Int(x - other.x, y - other.y);
  
  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    (other is Vector2Int && other.x == x && other.y == y);
  
  @override
  int get hashCode => x.hashCode ^ y.hashCode;
  
  @override
  String toString() => 'Vector2Int($x, $y)';
  
  /// 영점으로부터의 거리
  double get magnitude => (x * x + y * y).toDouble();
  
  /// 0,0 좌표
  static const Vector2Int zero = Vector2Int(0, 0);
  static const Vector2Int one = Vector2Int(1, 1);
} 