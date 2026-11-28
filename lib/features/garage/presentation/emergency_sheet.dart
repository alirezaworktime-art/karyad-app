import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/format/persian_format.dart';
import '../../catalog/domain/catalog.dart';

/// Official roadside-assistance and emergency numbers, one tap to call.
Future<void> showEmergencySheet(BuildContext context, {Maker? maker}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => _EmergencySheet(maker: maker),
  );
}

class _EmergencySheet extends StatelessWidget {
  const _EmergencySheet({this.maker});

  final Maker? maker;

  static const _ikco = ('امداد خودرو ایران‌خودرو', '096440');
  static const _saipa = ('امداد خودرو سایپا', '096550');
  static const _police = ('پلیس', '110');
  static const _ambulance = ('اورژانس', '115');
  static const _fire = ('آتش‌نشانی', '125');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final makerFirst = maker?.id == 'ikco' ? [_ikco, _saipa] : [_saipa, _ikco];
    final entries = [...makerFirst, _police, _ambulance, _fire];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'امداد و اضطراری',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            for (final (name, number) in entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                minTileHeight: 56,
                leading: const Icon(Icons.call_outlined),
                title: Text(name),
                subtitle: Text(PersianFormat.digits(number)),
                onTap: () => launchUrl(Uri(scheme: 'tel', path: number)),
              ),
            const SizedBox(height: 8),
            Text(
              'فقط به همین شماره‌های رسمی اعتماد کنید؛ تماس از شماره‌های دیگر به نام امداد خودروسازها معتبر نیست.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
