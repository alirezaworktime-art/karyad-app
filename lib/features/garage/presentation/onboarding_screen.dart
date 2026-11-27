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

/// Welcome → pick the car → odometer, sticker and color → the last time
/// key parts were replaced (optional). About a minute.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.controller});

  final GarageController controller;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

/// What the details step collected, kept while the history step is open.
class _CarDetails {
  const _CarDetails({
    required this.currentKm,
    required this.nextOilChangeKm,
    required this.color,
    required this.work,
  });

  final int currentKm;
  final int? nextOilChangeKm;
  final CarColor color;
  final bool work;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  String? _modelId;
  _CarDetails? _details;
  bool _saving = false;

  Future<void> _finish(Map<String, int> lastReplacedKm) async {
    final details = _details!;
    setState(() => _saving = true);
    await widget.controller.addVehicle(
      modelId: _modelId!,
      usage: details.work ? VehicleUsage.work : VehicleUsage.personal,
      currentKm: details.currentKm,
      color: details.color,
      nextOilChangeKm: details.nextOilChangeKm,
      lastReplacedKm: lastReplacedKm,
    );
  }

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
      2 => _DetailsStep(
        controller: widget.controller,
        modelId: _modelId!,
        initial: _details,
        onBack: () => setState(() => _step = 1),
        onNext: (details) => setState(() {
          _details = details;
          _step = 3;
        }),
      ),
      _ => _HistoryStep(
        controller: widget.controller,
        modelId: _modelId!,
        currentKm: _details!.currentKm,
        saving: _saving,
        onBack: () => setState(() => _step = 2),
        onFinish: _finish,
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
      label: 'مرحله ${PersianFormat.digits('$step')} از ۳',
      child: Row(
        children: [
          for (var i = 1; i <= 3; i++)
            Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsetsDirectional.only(end: i < 3 ? 6 : 0),
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
                            Flexible(
                              child: Text(
                                'تعویض روغن بعدی',
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall?.copyWith(
                                  color: BrandColors.muted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'در ۷۲٬۰۰۰',
                                overflow: TextOverflow.ellipsis,
                                style: text.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
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
    required this.initial,
    required this.onBack,
    required this.onNext,
  });

  final GarageController controller;
  final String modelId;
  final _CarDetails? initial;
  final VoidCallback onBack;
  final ValueChanged<_CarDetails> onNext;

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

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) return;
    _km.text = PersianFormat.number(initial.currentKm);
    final sticker = initial.nextOilChangeKm;
    if (sticker == null) {
      _noSticker = true;
    } else {
      _sticker.text = PersianFormat.number(sticker);
    }
    _color = initial.color;
    _work = initial.work;
  }

  @override
  void dispose() {
    _km.dispose();
    _sticker.dispose();
    super.dispose();
  }

  void _next() {
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
    widget.onNext(
      _CarDetails(
        currentKm: km!,
        nextOilChangeKm: sticker,
        color: _color,
        work: _work,
      ),
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
              FilledButton(onPressed: _next, child: const Text('ادامه')),
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

/// Optional: when key parts were last replaced. A blank row means "I don't
/// know"; that part then follows the factory milestones.
class _HistoryStep extends StatefulWidget {
  const _HistoryStep({
    required this.controller,
    required this.modelId,
    required this.currentKm,
    required this.saving,
    required this.onBack,
    required this.onFinish,
  });

  final GarageController controller;
  final String modelId;
  final int currentKm;
  final bool saving;
  final VoidCallback onBack;
  final ValueChanged<Map<String, int>> onFinish;

  @override
  State<_HistoryStep> createState() => _HistoryStepState();
}

class _HistoryStepState extends State<_HistoryStep> {
  late final List<MaintenanceItem> _items = widget.controller
      .startingHistoryItems(widget.modelId);
  late final Map<String, TextEditingController> _fields = {
    for (final item in _items) item.partId: TextEditingController(),
  };
  final Map<String, String> _errors = {};

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  void _finish() {
    final values = <String, int>{};
    final errors = <String, String>{};
    for (final entry in _fields.entries) {
      final raw = entry.value.text.trim();
      if (raw.isEmpty) continue;
      final km = PersianFormat.parseInt(raw);
      if (km == null) {
        errors[entry.key] = 'فقط عدد بنویس یا خالی بگذار';
      } else if (km > widget.currentKm) {
        errors[entry.key] =
            'از کیلومترشمار (${PersianFormat.number(widget.currentKm)}) بیشتر است';
      } else {
        values[entry.key] = km;
      }
    }
    if (errors.isNotEmpty) {
      setState(() => _errors
        ..clear()
        ..addAll(errors));
      return;
    }
    widget.onFinish(values);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final catalog = widget.controller.catalog;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'برگشت',
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.saving ? null : widget.onBack,
        ),
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveBody(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              const _Progress(step: 3),
              const SizedBox(height: 16),
              Text(
                'آخرین بار کِی عوض شده‌اند؟',
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'اگر یادت هست، عدد کیلومترشمار در آن روز را بنویس. '
                'اگر نه، خالی بگذار تا طبق برنامه‌ی کارخانه حساب کنیم. '
                'بعداً هم می‌شود ثبت کرد.',
                style: text.bodyMedium?.copyWith(color: BrandColors.muted),
              ),
              const SizedBox(height: 16),
              for (final item in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    key: Key('last-${item.partId}'),
                    controller: _fields[item.partId],
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) {
                      if (_errors.remove(item.partId) != null) setState(() {});
                    },
                    decoration: InputDecoration(
                      labelText: catalog.part(item.partId)?.nameFa ??
                          item.partId,
                      hintText: 'نمی‌دانم',
                      suffixText: 'کیلومتر',
                      errorText: _errors[item.partId],
                      errorMaxLines: 2,
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: widget.saving ? null : _finish,
                child: const Text('تمام'),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed:
                    widget.saving ? null : () => widget.onFinish(const {}),
                child: const Text('هیچ‌کدام یادم نیست، رد شو'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
