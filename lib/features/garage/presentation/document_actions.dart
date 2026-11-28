import 'package:material_ui/material_ui.dart';

import '../../../core/ui/jalali_date_picker.dart';
import '../application/garage_controller.dart';
import '../domain/vehicle.dart';

IconData documentIcon(VehicleDocument document) => switch (document) {
  VehicleDocument.insurance => Icons.verified_user_outlined,
  VehicleDocument.inspection => Icons.fact_check_outlined,
};

/// Asks for a document's expiry date (as printed on it) and saves it.
Future<void> pickDocumentExpiry(
  BuildContext context,
  GarageController controller,
  Vehicle vehicle,
  VehicleDocument document,
) async {
  final picked = await showJalaliDatePicker(
    context,
    title: 'اعتبار ${document.nameFa} تا چه تاریخی است؟',
    initial: vehicle.documentExpiry[document] ?? controller.now,
  );
  if (picked != null) {
    await controller.setDocumentExpiry(vehicle.id, document, picked);
  }
}
