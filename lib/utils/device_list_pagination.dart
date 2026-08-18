/// Client-side windowing for large connected/banned device lists.
///
/// RouterOS returns all DHCP leases in one API call; we paginate in the UI
/// and scope live-traffic polling to the visible window + buffer.
abstract final class DeviceListPagination {
  static const int initialPageSize = 20;
  static const int pageSize = 20;
  static const int prefetchThreshold = 5;

  /// Extra rows beyond the visible window included in traffic polling.
  static const int trafficBuffer = 8;

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
