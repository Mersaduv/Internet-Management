/// Client-side windowing for large connected/banned device lists.
///
/// RouterOS returns all DHCP leases in one API call; we paginate in the UI.
/// Live-traffic polling is scoped per visible list row (see
/// [TrafficListItemVisibility]), not by a fixed device count cap.
abstract final class DeviceListPagination {  static const int initialPageSize = 20;
  static const int pageSize = 20;
  static const int prefetchThreshold = 5;

  /// Extra rows beyond the visible viewport for list prefetch only.
  static const int trafficBuffer = 3;

  /// Approximate list row height for scroll prefetch estimation (px).
  static const double estimatedRowHeight = 88;

  static int clampLimit(int limit, int total) {
    if (total <= 0) {
      return 0;
    }
    if (limit <= 0) {
      return initialPageSize.clamp(1, total);
    }
    return limit.clamp(1, total);
  }
}
