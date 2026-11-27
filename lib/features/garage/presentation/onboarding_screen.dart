import 'package:material_ui/material_ui.dart';

import '../../../core/format/persian_format.dart';
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
  String _makerId = 'ikco';
  String? _modelId;
  OilType _oil = OilType.fullSynthetic;
  int _dailyKm = 40;
  final _kmController = TextEditingController();
  String? _kmError;
  bool _saving = false;

  Catalog get _catalog => widget.controller.catalog;

  @override
  void dispose() {
    _kmController.dispose();
    super.dispose();
  }

  void _chooseUsage(VehicleUsage usage) => setState(() {
    _usage = usage;
    _dailyKm = usage == VehicleUsage.work ? 150 : 40;
    _step = 1;
  });

  Future<void> _finish() async {
    final km = PersianFormat.parseInt(_kmController.text);
    if (km == null || km < 0 || km > 2000000) {
      setState(() => _kmError = 'کیلومتر فعلی ماشین را وارد کنید');
      return;
    }
    setState(() => _saving = true);
    await widget.controller.addVehicle(
      modelId: _modelId!,
      usage: _usage!,
      oilType: _oil,
      currentKm: km,
      averageDailyKm: _dailyKm,
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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: switch (_step) {
            0 => _UsageStep(key: const ValueKey(0), onChoose: _chooseUsage),
            1 => _ModelStep(
              key: const ValueKey(1),
              catalog: _catalog,
              makerId: _makerId,
              selectedModelId: _modelId,
              onMaker: (id) => setState(() {
                _makerId = id;
                _modelId = null;
              }),
              onModel: (id) => setState(() {
                _modelId = id;
                _step = 2;
              }),
            ),
            _ => _DetailsStep(
              key: const ValueKey(2),
              modelName: _catalog.model(_modelId!)?.nameFa ?? '',
              kmController: _kmController,
              kmError: _kmError,
              dailyKm: _dailyKm,
              oil: _oil,
              saving: _saving,
              onDailyKm: (v) => setState(() => _dailyKm = v),
              onOil: (v) => setState(() => _oil = v),
              onKmChanged: () => setState(() => _kmError = null),
              onFinish: _finish,
            ),
          },
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
        Text(
          'مرحله ${PersianFormat.digits('$step')} از ۳',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: theme.textTheme.bodyMedium),
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
          subtitle: 'برای این‌که زمان سرویس‌ها درست حساب شود.',
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
          body: 'اسنپ، تپسی، تاکسی یا پیک. سرویس‌ها طبق «شرایط سخت» کارخانه زودتر یادآوری می‌شوند.',
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
                child: Icon(icon, color: theme.colorScheme.primary, size: 28),
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
                    Text(body, style: theme.textTheme.bodyMedium),
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

class _ModelStep extends StatelessWidget {
  const _ModelStep({
    super.key,
    required this.catalog,
    required this.makerId,
    required this.selectedModelId,
    required this.onMaker,
    required this.onModel,
  });

  final Catalog catalog;
  final String makerId;
  final String? selectedModelId;
  final ValueChanged<String> onMaker;
  final ValueChanged<String> onModel;

  @override
  Widget build(BuildContext context) {
    final models = catalog.modelsOfMaker(makerId);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _StepHeader(step: 2, title: 'ماشینت کدام است؟'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final maker in catalog.makers)
              ChoiceChip(
                label: Text(maker.nameFa),
                selected: maker.id == makerId,
                onSelected: (_) => onMaker(maker.id),
              ),
          ],
        ),
        const SizedBox(height: 16),
        for (final model in models)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                minTileHeight: 56,
                title: Text(model.nameFa),
                trailing: const Icon(Icons.chevron_right),
                selected: model.id == selectedModelId,
                onTap: () => onModel(model.id),
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
    required this.kmError,
    required this.dailyKm,
    required this.oil,
    required this.saving,
    required this.onDailyKm,
    required this.onOil,
    required this.onKmChanged,
    required this.onFinish,
  });

  final String modelName;
  final TextEditingController kmController;
  final String? kmError;
  final int dailyKm;
  final OilType oil;
  final bool saving;
  final ValueChanged<int> onDailyKm;
  final ValueChanged<OilType> onOil;
  final VoidCallback onKmChanged;
  final VoidCallback onFinish;

  static const _dailyOptions = [20, 40, 80, 150, 250];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _StepHeader(step: 3, title: modelName, subtitle: 'دو سؤال کوتاه دیگر.'),
        TextField(
          controller: kmController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onChanged: (_) => onKmChanged(),
          decoration: InputDecoration(
            labelText: 'کیلومتر فعلی ماشین',
            hintText: '۸۵٬۰۰۰',
            suffixText: 'کیلومتر',
            errorText: kmError,
          ),
        ),
        const SizedBox(height: 24),
        Text('روزی چقدر رانندگی می‌کنی؟', style: theme.textTheme.titleSmall),
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
        const SizedBox(height: 24),
        Text('چه روغنی می‌ریزی؟', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<OilType>(
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
        const SizedBox(height: 8),
        Text(
          'نمی‌دانی؟ همان تمام‌سنتتیک بماند؛ بعداً عوضش می‌کنی.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: saving ? null : onFinish,
          child: const Text('شروع'),
        ),
      ],
    );
  }
}
