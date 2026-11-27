import 'package:material_ui/material_ui.dart';

import '../../../core/format/persian_format.dart';
import '../../../core/ui/responsive_body.dart';
import '../../catalog/domain/catalog.dart';
import '../application/garage_controller.dart';
import '../domain/vehicle.dart';

/// Three short steps: how the car is used, which car, current odometer.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.controller});

  final GarageController controller;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  VehicleUsage? _usage;
  String? _modelId;
  OilType _oil = OilType.fullSynthetic;
  int _dailyKm = 40;
  bool _oilUnknown = false;
  final _kmController = TextEditingController();
  final _lastOilController = TextEditingController();
  String? _kmError;
  String? _oilError;
  bool _saving = false;

  Catalog get _catalog => widget.controller.catalog;

  @override
  void dispose() {
    _kmController.dispose();
    _lastOilController.dispose();
    super.dispose();
  }

  void _chooseUsage(VehicleUsage usage) => setState(() {
    _usage = usage;
    _dailyKm = usage == VehicleUsage.work ? 150 : 40;
    _step = 1;
  });

  Future<void> _finish() async {
    final km = PersianFormat.parseInt(_kmController.text);
    final lastOil = _oilUnknown
        ? null
        : PersianFormat.parseInt(_lastOilController.text);
    String? kmError;
    String? oilError;
    if (km == null || km > 2000000) {
      kmError = 'کیلومتر فعلی ماشین را وارد کنید';
    }
    if (!_oilUnknown && lastOil == null) {
      oilError = 'کیلومتر آخرین تعویض را بنویس یا «یادم نیست» را بزن';
    } else if (lastOil != null && km != null && lastOil > km) {
      oilError = 'از کیلومتر فعلی بیشتر است';
    }
    if (kmError != null || oilError != null) {
      setState(() {
        _kmError = kmError;
        _oilError = oilError;
      });
      return;
    }
    setState(() => _saving = true);
    await widget.controller.addVehicle(
      modelId: _modelId!,
      usage: _usage!,
      oilType: _oil,
      currentKm: km!,
      averageDailyKm: _dailyKm,
      lastOilChangeKm: lastOil,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('کاریاد'),
        leading: _step == 0
            ? null
            : IconButton(
                tooltip: 'مرحله قبل',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step -= 1),
              ),
      ),
      body: SafeArea(
        child: ResponsiveBody(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: switch (_step) {
              0 => _UsageStep(key: const ValueKey(0), onChoose: _chooseUsage),
              1 => _ModelStep(
                key: const ValueKey(1),
                catalog: _catalog,
                onModel: (id) => setState(() {
                  _modelId = id;
                  _step = 2;
                }),
              ),
              _ => _DetailsStep(
                key: const ValueKey(2),
                modelName: _catalog.model(_modelId!)?.nameFa ?? '',
                kmController: _kmController,
                lastOilController: _lastOilController,
                kmError: _kmError,
                oilError: _oilError,
                oilUnknown: _oilUnknown,
                dailyKm: _dailyKm,
                oil: _oil,
                saving: _saving,
                onDailyKm: (v) => setState(() => _dailyKm = v),
                onOil: (v) => setState(() => _oil = v),
                onOilUnknown: (v) => setState(() {
                  _oilUnknown = v;
                  _oilError = null;
                }),
                onEdited: () => setState(() {
                  _kmError = null;
                  _oilError = null;
                }),
                onFinish: _finish,
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.title, this.subtitle});

  final int step;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 1; i <= 3; i++)
              Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsetsDirectional.only(end: i < 3 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: i <= step
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

class _UsageStep extends StatelessWidget {
  const _UsageStep({super.key, required this.onChoose});

  final ValueChanged<VehicleUsage> onChoose;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _StepHeader(
          step: 1,
          title: 'با ماشینت چه کار می‌کنی؟',
          subtitle: 'تا زمان سرویس‌ها را درست حساب کنیم.',
        ),
        _ChoiceCard(
          icon: Icons.directions_car_outlined,
          title: 'ماشین شخصی',
          body: 'رفت‌وآمد روزمره و سفر',
          onTap: () => onChoose(VehicleUsage.personal),
        ),
        const SizedBox(height: 12),
        _ChoiceCard(
          icon: Icons.local_taxi_outlined,
          title: 'با ماشینم کار می‌کنم',
          body: 'اسنپ، تپسی، تاکسی یا پیک. یادآورها طبق «شرایط سخت» کارخانه زودتر می‌آیند.',
          onTap: () => onChoose(VehicleUsage.work),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  icon,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// One searchable list of every model, most common cars first, each with
/// its maker underneath. Typing «پرا» finds پراید.
class _ModelStep extends StatefulWidget {
  const _ModelStep({super.key, required this.catalog, required this.onModel});

  final Catalog catalog;
  final ValueChanged<String> onModel;

  /// Most common cars on Iranian roads, shown first.
  static const popular = [
    'pride-131',
    '206-tip2',
    '206-tip5',
    '405',
    'pars-xu7p',
    'samand-lx',
    'tiba',
    'quick',
    'dena-plus',
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
            entry.$1.id.contains(q.toLowerCase()))
          entry,
    ];
  }

  /// Folds Arabic ي/ك into Persian ی/ک and digits to Latin, so any keyboard
  /// finds the model.
  static String _normalize(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(switch (char) {
        'ي' => 'ی',
        'ك' => 'ک',
        _ => PersianFormat.parseInt(char)?.toString() ?? char,
      });
    }
    return buffer.toString().replaceAll('‌', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final models = _models();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _StepHeader(step: 2, title: 'ماشینت کدام است؟'),
        TextField(
          key: const Key('model-search'),
          onChanged: (v) => setState(() => _query = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'جستجو: پراید، ۲۰۶، دنا…',
          ),
        ),
        const SizedBox(height: 12),
        if (models.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'این مدل هنوز در فهرست نیست. به‌زودی اضافه می‌شود.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        for (final (model, maker) in models)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                minTileHeight: 60,
                title: Text(
                  model.nameFa,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: maker == null ? null : Text(maker.nameFa),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => widget.onModel(model.id),
              ),
            ),
          ),
      ],
    );
  }
}

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    super.key,
    required this.modelName,
    required this.kmController,
    required this.lastOilController,
    required this.kmError,
    required this.oilError,
    required this.oilUnknown,
    required this.dailyKm,
    required this.oil,
    required this.saving,
    required this.onDailyKm,
    required this.onOil,
    required this.onOilUnknown,
    required this.onEdited,
    required this.onFinish,
  });

  final String modelName;
  final TextEditingController kmController;
  final TextEditingController lastOilController;
  final String? kmError;
  final String? oilError;
  final bool oilUnknown;
  final int dailyKm;
  final OilType oil;
  final bool saving;
  final ValueChanged<int> onDailyKm;
  final ValueChanged<OilType> onOil;
  final ValueChanged<bool> onOilUnknown;
  final VoidCallback onEdited;
  final VoidCallback onFinish;

  static const _dailyOptions = [20, 40, 80, 150, 250];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
    );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _StepHeader(
          step: 3,
          title: modelName,
          subtitle: 'چند عدد ساده؛ بعداً هم قابل تغییر است.',
        ),
        TextField(
          key: const Key('current-km'),
          controller: kmController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          onChanged: (_) => onEdited(),
          decoration: InputDecoration(
            labelText: 'کیلومتر فعلی ماشین',
            hintText: '۸۵٬۰۰۰',
            suffixText: 'کیلومتر',
            errorText: kmError,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('last-oil-km'),
          controller: lastOilController,
          enabled: !oilUnknown,
          keyboardType: TextInputType.number,
          onChanged: (_) => onEdited(),
          decoration: InputDecoration(
            labelText: 'آخرین تعویض روغن در چه کیلومتری بود؟',
            hintText: '۸۲٬۰۰۰',
            suffixText: 'کیلومتر',
            errorText: oilError,
            helperText: 'روی برچسب پشت شیشه یا فاکتور تعویض‌روغنی نوشته شده.',
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilterChip(
            label: const Text('یادم نیست'),
            selected: oilUnknown,
            onSelected: onOilUnknown,
          ),
        ),
        const SizedBox(height: 20),
        Text('روزی چقدر رانندگی می‌کنی؟', style: label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in _dailyOptions)
              ChoiceChip(
                label: Text('${PersianFormat.number(option)} کیلومتر'),
                selected: option == dailyKm,
                onSelected: (_) => onDailyKm(option),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text('چه روغنی می‌ریزی؟', style: label),
        const SizedBox(height: 8),
        SegmentedButton<OilType>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: OilType.mineral, label: Text('معدنی')),
            ButtonSegment(
              value: OilType.semiSynthetic,
              label: Text('نیمه‌سنتتیک'),
            ),
            ButtonSegment(
              value: OilType.fullSynthetic,
              label: Text('تمام‌سنتتیک'),
            ),
          ],
          selected: {oil},
          onSelectionChanged: (set) => onOil(set.first),
        ),
        const SizedBox(height: 6),
        Text(
          'نمی‌دانی؟ تمام‌سنتتیک بماند؛ بعداً عوضش می‌کنی.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: saving ? null : onFinish,
          child: const Text('شروع'),
        ),
      ],
    );
  }
}
