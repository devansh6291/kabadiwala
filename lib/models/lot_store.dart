import 'lot.dart';

class LotStore {
  static final List<Lot> _lots = [];

  static void addLot(Lot lot) {
    _lots.add(lot);
  }

  static List<Lot> getAllLots() {
    return _lots;
  }
}