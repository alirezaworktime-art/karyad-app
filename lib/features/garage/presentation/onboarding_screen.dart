import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/format/persian_format.dart';
import '../../../core/ui/responsive_body.dart';
import '../../catalog/domain/body_type.dart';
import '../../catalog/domain/catalog.dart';
import '../application/garage_controller.dart';
import '../domain/vehicle.dart';
import 'widgets/car_illustration.dart';
import 'widgets/karyad_logo.dart';

/// Welcome → pick the car → odometer, sticker and color. Under a minute.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.controller});

  final GarageController controller;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  String? _modelId;

  @override
  Widget build(BuildContext context) {
    final catalog = widget.controller.catalog;
    final Widget page = switch (_step) {
      0 => _WelcomeStep(onStart: () => setState(() => _step = 1)),
      1 => _ModelStep(
        catalog: catalog,
        onBack: () => setState(() => _step = 0),
        onPick: (id) => setState(() {
          _modelId = id;
          _step = 2;
        }),
      ),
      _ => _DetailsStep(
        controller: widget.controller,
        modelId: _modelId!,
        onBack: () => setState(() => _step = 1),
      ),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: KeyedSubtree(key: ValueKey(_step), child: page),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'مرحله ${PersianFormat.digits('$step')} از ۲',
      child: Row(
        children: [
          for (var i = 1; i <= 2; i++)
            Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsetsDirectional.only(end: i < 2 ? 6 : 0),
                decoration: BoxDecoration(
                  color: i <= step
                      ? BrandColors.violet
                      : BrandColors.violetBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ResponsiveBody(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: KaryadLogo(size: 56),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                  decoration: BoxDecoration(
                    color: BrandColors.violetLight,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      const CarIllustration(
                        bodyType: BodyType.sedan,
                        color: BrandColors.violet,
                        width: 260,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'تعویض روغن بعدی',
                              style: text.bodySmall?.copyWith(
                                color: BrandColors.muted,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'در ۷۲٬۰۰۰',
                              style: text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'سرویس ماشینت دیگر یادت نمی‌رود',
                  style: text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'طبق دفترچه‌ی کارخانه می‌گوییم هر قطعه در چه کیلومتری و تا چه تاریخی باید عوض شود.',
                  style: text.bodyLarge?.copyWith(color: BrandColors.muted),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: onStart,
                  child: const Text('شروع کنیم'),
                ),
                const SizedBox(height: 10),
                Text(
                  'کمتر از یک دقیقه · بدون ثبت‌نام و شماره تلفن',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: BrandColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One searchable list of every model, common cars first, each with its
/// body-type drawing and maker.
class _ModelStep extends StatefulWidget {
  const _ModelStep({
    required this.catalog,
    required this.onBack,
    required this.onPick,
  });

  final Catalog catalog;
  final VoidCallback onBack;
  final ValueChanged<String> onPick;

  static const popular = [
    'pride-131',
    '206-tip5',
    '405',
    'tiba',
    'dena-plus',
    'pars-xu7p',
    'samand-lx',
    'quick',
    '206-tip2',
    'saina',
    'shahin',
    '207',
    'rana-plus',
    'tara',
    'pride-132',
    'saba',
  ];

  @override
  State<_ModelStep> createState() => _ModelStepState();
}

class _ModelStepState extends State<_ModelStep> {
  String _query = '';

  List<(VehicleModel, Maker?)> _models() {
    final catalog = widget.catalog;
    final all = <(VehicleModel, Maker?)>[
      for (final group in catalog.groups)
        for (final model in group.models) (model, catalog.maker(group.makerId)),
    ];
    int rank(VehicleModel m) {
      final i = _ModelStep.popular.indexOf(m.id);
      return i < 0 ? _ModelStep.popular.length : i;
    }

    all.sort((a, b) => rank(a.$1).compareTo(rank(b.$1)));
    final q = _normalize(_query.trim());
    if (q.isEmpty) return all;
    return [
      for (final entry in all)
        if (_normalize(entry.$1.nameFa).contains(q) ||
            _normalize(entry.$2?.nameFa ?? '').contains(q) ||
            entry.$1.id.contains(q.toLowerCase()))
          entry,
    ];
  }

  /// Folds Arabic ي/ك into Persian ی/ک, digits to Latin and half-spaces to
  /// spaces, so any keyboard finds the model.
  static String _normalize(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(switch (char) {
        'ي' => 'ی',
        'ك' => 'ک',
        '‌' => ' ',
        _ => PersianFormat.parseInt(char)?.toString() ?? char,
      });
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final models = _models();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'برگشت',
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveBody(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              const _Progress(step: 1),
              const SizedBox(height: 18),
              Text(
                'ماشینت کدام است؟',
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('model-search'),
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'جستجو: پراید، ۲۰۶، دنا…',
                ),
              ),
              const SizedBox(height: 14),
              if (_query.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, right: 4),
                  child: Text(
                    'پرتکرارها',
                    style: text.bodySmall?.copyWith(color: BrandColors.muted),
                  ),
                ),
              if (models.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'این مدل هنوز در فهرست نیست. به‌زودی اضافه می‌شود.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: BrandColors.muted),
                  ),
                ),
              if (models.isNotEmpty)
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < models.length; i++) ...[
                        if (i > 0) const Divider(),
                        _ModelTile(
                          model: models[i].$1,
                          maker: models[i].$2,
                          onTap: () => widget.onPick(models[i].$1.id),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({
    required this.model,
    required this.maker,
    required this.onTap,
  });

  final VehicleModel model;
  final Maker? maker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListTile(
      onTap: onTap,
      minTileHeight: 64,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      leading: CarIllustration(
        bodyType: BodyTypes.of(model.id),
        color: const Color(0xFFCFC4E8),
        width: 56,
      ),
      title: Text(
        model.nameFa,
        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: maker == null
          ? null
          : Text(
              maker!.nameFa,
              style: text.bodySmall?.copyWith(color: BrandColors.muted),
            ),
      trailing: const Icon(Icons.chevron_right, color: BrandColors.muted),
    );
  }
}

class _DetailsStep extends StatefulWidget {
  const _DetailsStep({
    required this.controller,
    required this.modelId,
    required this.onBack,
  });

  final GarageController controller;
  final String modelId;
  final VoidCallback onBack;

  @override
  State<_DetailsStep> createState() => _DetailsStepState();
}

class _DetailsStepState extends State<_DetailsStep> {
  final _km = TextEditingController();
  final _sticker = TextEditingController();
  bool _noSticker = false;
  bool _work = false;
  CarColor _color = CarColor.white;
  String? _kmError;
  String? _stickerError;
  bool _saving = false;

  @override
  void dispose() {
    _km.dispose();
    _sticker.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final km = PersianFormat.parseInt(_km.text);
    final sticker = _noSticker ? null : PersianFormat.parseInt(_sticker.text);
    String? kmError;
    String? stickerError;
    if (km == null || km > 2000000) {
      kmError = 'عدد کیلومترشمار را بنویس';
    }
    if (!_noSticker && sticker == null) {
      stickerError = 'عدد برچسب را بنویس یا «برچسب ندارم» را بزن';
    } else if (sticker != null && km != null && sticker <= km) {
      stickerError = 'این عدد از کیلومترشمار کمتر است؛ یعنی وقت تعویض روغن گذشته. «برچسب ندارم» را بزن.';
    }
    if (kmError != null || stickerError != null) {
      setState(() {
        _kmError = kmError;
        _stickerError = stickerError;
      });
      return;
    }
    setState(() => _saving = true);
    await widget.controller.addVehicle(
      modelId: widget.modelId,
      usage: _work ? VehicleUsage.work : VehicleUsage.personal,
      currentKm: km!,
      color: _color,
      nextOilChangeKm: sticker,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final label = text.titleSmall?.copyWith(fontWeight: FontWeight.w700);
    final model = widget.controller.catalog.model(widget.modelId);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'برگشت',
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveBody(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              const _Progress(step: 2),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BrandColors.violetLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    CarIllustration(
                      bodyType: BodyTypes.of(widget.modelId),
                      color: Color(_color.argb),
                      taxiSign: _work,
                      width: 220,
                      semanticLabel: '${model?.nameFa ?? ''} ${_color.nameFa}',
                    ),
                    Text(
                      model?.nameFa ?? '',
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('کیلومترشمار الان چند نشان می‌دهد؟', style: label),
              const SizedBox(height: 8),
              TextField(
                key: const Key('current-km'),
                controller: _km,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                onChanged: (_) => setState(() => _kmError = null),
                decoration: InputDecoration(
                  hintText: '۶۲٬۴۰۰',
                  suffixText: 'کیلومتر',
                  errorText: _kmError,
                  errorMaxLines: 3,
                  helperText: 'همان عدد صفحه‌ی جلوی فرمان.',
                ),
              ),
              const SizedBox(height: 20),
              Text('روی برچسب تعویض روغن چه عددی نوشته؟', style: label),
              const SizedBox(height: 8),
              TextField(
                key: const Key('sticker-km'),
                controller: _sticker,
                enabled: !_noSticker,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() => _stickerError = null),
                decoration: InputDecoration(
                  hintText: 'مثلاً ۷۲٬۰۰۰',
                  suffixText: 'کیلومتر',
                  errorText: _stickerError,
                  errorMaxLines: 3,
                  helperText: 'برچسب کوچک گوشه‌ی شیشه‌ی جلو.',
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilterChip(
                  label: const Text('برچسب ندارم'),
                  selected: _noSticker,
                  onSelected: (v) => setState(() {
                    _noSticker = v;
                    _stickerError = null;
                  }),
                ),
              ),
              const SizedBox(height: 16),
              Text('رنگ ماشین', style: label),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in CarColor.values)
                    _ColorDot(
                      color: c,
                      selected: c == _color,
                      onTap: () => setState(() => _color = c),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                child: SwitchListTile(
                  value: _work,
                  onChanged: (v) => setState(() => _work = v),
                  title: Text(
                    'با این ماشین مسافرکشی می‌کنم',
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'اسنپ، تپسی، تاکسی، پیک · سرویس‌ها زودتر یادآوری می‌شوند',
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _saving ? null : _finish,
                child: const Text('تمام'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final CarColor color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: color.nameFa,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Color(color.argb),
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? BrandColors.violet : BrandColors.violetBorder,
              width: selected ? 3 : 1,
            ),
          ),
          child: selected
              ? Icon(
                  Icons.check,
                  size: 20,
                  color: Color(color.argb).computeLuminance() > 0.5
                      ? BrandColors.violet
                      : Colors.white,
                )
              : null,
        ),
      ),
    );
  }
}
