import 'dart:async';

import 'package:flutter/material.dart';
import 'fa.dart';

import '../data/cache.dart';
import '../timetable/hr_api.dart';
import '../timetable/models.dart';
import 'app_theme.dart';
import 'copy.dart';
import 'trips_page.dart';

const _routes = <(String, String)>[
  ('Chandigarh', 'Delhi'),
  ('Delhi', 'Chandigarh'),
  ('Gurgaon', 'Delhi'),
  ('Hisar', 'Delhi'),
  ('Rohtak', 'Delhi'),
  ('Ambala', 'Chandigarh'),
];

const _cities = [
  'Chandigarh',
  'Delhi',
  'Gurgaon',
  'Hisar',
  'Rohtak',
  'Ambala',
  'Karnal',
  'Panipat',
  'Faridabad',
  'Sonipat',
];

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.api, this.cache});

  final HrApi? api;
  final AppCache? cache;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final HrApi _api = widget.api ?? HrApi();
  final _boardingText = TextEditingController();
  final _destinationText = TextEditingController();
  final _panelKey = GlobalKey();
  Timer? _debounce;
  int _searchId = 0;
  List<Station> _suggestions = const [];
  bool _forBoarding = true;
  bool _loading = false;
  String? _hint;
  String? _formError;
  Station? _boarding;
  Station? _destination;
  List<RecentPair> _recent = const [];
  bool _routing = false;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final rows = await widget.cache?.recents() ?? const <RecentPair>[];
    if (!mounted) return;
    setState(() => _recent = rows);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _boardingText.dispose();
    _destinationText.dispose();
    super.dispose();
  }

  TextEditingController get _activeText => _forBoarding ? _boardingText : _destinationText;

  void _onChanged(String value, {required bool boarding}) {
    _debounce?.cancel();
    final id = ++_searchId;
    setState(() {
      _forBoarding = boarding;
      if (boarding) {
        if (_boarding?.stationName != value) _boarding = null;
      } else if (_destination?.stationName != value) {
        _destination = null;
      }
      _hint = null;
      _formError = null;
    });
    final query = value.trim();
    final held = boarding ? _boarding : _destination;
    if (held != null && held.stationName == value) {
      setState(() {
        _suggestions = const [];
        _loading = false;
      });
      return;
    }
    if (query.length < 2) {
      setState(() {
        _suggestions = const [];
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query, id));
  }

  Future<void> _search(String query, int id) async {
    setState(() => _loading = true);
    try {
      final list = await _api.stations(query);
      if (!mounted || id != _searchId) return;
      setState(() {
        _suggestions = list;
        _loading = false;
        _hint = list.isEmpty && query.toLowerCase().contains('gurugram')
            ? LocaleHost.copyOf(context).gurgaon
            : null;
      });
      _revealPanel();
    } on HrException catch (error) {
      if (!mounted || id != _searchId) return;
      setState(() {
        _loading = false;
        _hint = error.message;
        _suggestions = const [];
      });
    } catch (_) {
      if (!mounted || id != _searchId) return;
      setState(() {
        _loading = false;
        _hint = LocaleHost.copyOf(context).timetableDown;
        _suggestions = const [];
      });
    }
  }

  void _revealPanel() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _panelKey.currentContext;
      if (target == null || !target.mounted) return;
      final reduce = MediaQuery.disableAnimationsOf(target);
      Scrollable.ensureVisible(
        target,
        alignment: 0.15,
        duration: reduce ? Duration.zero : const Duration(milliseconds: 200),
      );
    });
  }

  void _activate(bool boarding) {
    if (_forBoarding != boarding) {
      _debounce?.cancel();
      _searchId++;
      setState(() {
        _forBoarding = boarding;
        _suggestions = const [];
        _loading = false;
        _hint = null;
        _formError = null;
      });
    }
    final text = (boarding ? _boardingText : _destinationText).text.trim();
    if (text.length >= 2) _onChanged(text, boarding: boarding);
  }

  void _useCity(String city) {
    final controller = _activeText;
    controller.value = TextEditingValue(
      text: city,
      selection: TextSelection.collapsed(offset: city.length),
    );
    _onChanged(city, boarding: _forBoarding);
  }

  void _pick(Station station) {
    _debounce?.cancel();
    _searchId++;
    setState(() {
      if (_forBoarding) {
        _boarding = station;
        _boardingText.text = station.stationName;
        if (_destination == null) _forBoarding = false;
      } else {
        _destination = station;
        _destinationText.text = station.stationName;
        if (_boarding == null) _forBoarding = true;
      }
      _suggestions = const [];
      _hint = null;
      _formError = null;
      _loading = false;
    });
  }

  void _swap() {
    _debounce?.cancel();
    _searchId++;
    final boarding = _boarding;
    final destination = _destination;
    final from = _boardingText.text;
    final to = _destinationText.text;
    setState(() {
      _boarding = destination;
      _destination = boarding;
      _boardingText.text = to;
      _destinationText.text = from;
      _suggestions = const [];
      _hint = null;
      _formError = null;
      _loading = false;
    });
  }

  Station? _best(List<Station> list, String query) {
    if (list.isEmpty) return null;
    final q = query.toLowerCase();
    for (final station in list) {
      if (station.stationName.toLowerCase() == q) return station;
    }
    final starts = [
      for (final station in list)
        if (station.stationName.toLowerCase().startsWith(q)) station,
    ];
    if (starts.isNotEmpty) {
      starts.sort((a, b) => a.stationName.length.compareTo(b.stationName.length));
      return starts.first;
    }
    return list.first;
  }

  Future<void> _route(String fromQuery, String toQuery) async {
    if (_routing) return;
    setState(() {
      _routing = true;
      _formError = null;
    });
    try {
      final fromList = await _api.stations(fromQuery);
      final toList = await _api.stations(toQuery);
      if (!mounted) return;
      final from = _best(fromList, fromQuery);
      final to = _best(toList, toQuery);
      if (from == null || to == null) {
        setState(() {
          _routing = false;
          _formError = LocaleHost.copyOf(context).couldNotMatch(fromQuery, toQuery);
        });
        return;
      }
      setState(() {
        _routing = false;
        _boarding = from;
        _destination = to;
        _boardingText.text = from.stationName;
        _destinationText.text = to.stationName;
        _suggestions = const [];
        _hint = null;
      });
      await _open(from, to);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _routing = false;
        _formError = LocaleHost.copyOf(context).timetableDown;
      });
    }
  }

  Future<void> _open(Station boarding, Station destination) async {
    await widget.cache?.remember(boarding, destination);
    if (!mounted) return;
    await _loadRecent();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TripsPage(
          api: _api,
          cache: widget.cache,
          boarding: boarding,
          destination: destination,
        ),
      ),
    );
  }

  void _submit() {
    final boarding = _boarding;
    final destination = _destination;
    if (boarding == null || destination == null) {
      setState(() => _formError = LocaleHost.copyOf(context).chooseBoth);
      return;
    }
    _open(boarding, destination);
  }

  bool get _panelOpen {
    final text = _activeText.text.trim();
    final picked = _forBoarding ? _boarding : _destination;
    if (picked != null && picked.stationName == text) return false;
    return text.length >= 2;
  }

  @override
  Widget build(BuildContext context) {
    final copy = LocaleHost.copyOf(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Row(
              children: [
                const _BusMark(),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    copy.appName,
                    style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const LanguageButton(),
                const ThemeModeButton(),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              copy.findBus,
              style: text.displaySmall?.copyWith(fontWeight: FontWeight.w800, height: 1.05),
            ),
            const SizedBox(height: 16),
            _ticket(context),
            if (!_panelOpen) ...[
              const SizedBox(height: 28),
              _Heading(copy.routes, hint: copy.routesHint),
              for (final route in _routes)
                _RouteRow(
                  label: '${copy.place(route.$1)} → ${copy.place(route.$2)}',
                  onTap: _routing ? null : () => _route(route.$1, route.$2),
                ),
              if (_recent.isNotEmpty) ...[
                const SizedBox(height: 20),
                _Heading(copy.recent),
                for (final pair in _recent)
                  _RouteRow(
                    label: '${copy.place(pair.fromName)} → ${copy.place(pair.toName)}',
                    icon: Far.clockRotateLeft,
                    onTap: () => _open(pair.from, pair.to),
                  ),
              ],
              const SizedBox(height: 20),
              _Heading(_forBoarding ? copy.citiesForFrom : copy.citiesForTo, hint: copy.cityHint),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final city in _cities)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 44),
                        foregroundColor: scheme.onSurface,
                        side: BorderSide(color: scheme.outline, width: 1.5),
                        shape: const StadiumBorder(),
                        textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      onPressed: () => _useCity(city),
                      child: Text(copy.place(city)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _ticket(BuildContext context) {
    final copy = LocaleHost.copyOf(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline, width: 1.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(
            label: copy.from,
            hint: copy.place('Chandigarh'),
            icon: Fa.circleDot,
            iconColor: scheme.onSurfaceVariant,
            controller: _boardingText,
            picked: _boarding != null,
            onTap: () => _activate(true),
            onChanged: (value) => _onChanged(value, boarding: true),
          ),
          if (_forBoarding && _panelOpen) _panel(),
          Row(
            children: [
              const SizedBox(width: 22),
              Container(width: 2, height: 20, color: scheme.outline),
              const Spacer(),
              IconButton.outlined(
                tooltip: copy.swap,
                style: IconButton.styleFrom(
                  side: BorderSide(color: scheme.outline, width: 1.5),
                  minimumSize: const Size(40, 40),
                ),
                onPressed: _swap,
                icon: Icon(Far.arrowsUpDown, size: 16, color: scheme.primary),
              ),
            ],
          ),
          _field(
            label: copy.to,
            hint: copy.place('Delhi'),
            icon: Fa.locationDot,
            iconColor: scheme.primary,
            controller: _destinationText,
            picked: _destination != null,
            onTap: () => _activate(false),
            onChanged: (value) => _onChanged(value, boarding: false),
          ),
          if (!_forBoarding && _panelOpen) _panel(),
          if (_formError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_formError!, style: TextStyle(color: scheme.error)),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _routing ? null : _submit,
            icon: const Icon(Far.magnifyingGlass, size: 18),
            label: Text(_routing ? copy.findingStops : copy.searchBuses),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required TextEditingController controller,
    required bool picked,
    required VoidCallback onTap,
    required ValueChanged<String> onChanged,
  }) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 46, child: Icon(icon, size: 18, color: iconColor)),
        Expanded(
          child: TextField(
            controller: controller,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              hintText: hint,
              suffixIcon: picked ? Icon(Fa.check, size: 16, color: scheme.secondary) : null,
            ),
            textInputAction: TextInputAction.search,
            onTap: onTap,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _panel() {
    final scheme = Theme.of(context).colorScheme;
    final count = _suggestions.length;
    final height = _loading || count == 0 ? 72.0 : (count * 52.0).clamp(52.0, 260.0);
    return Container(
      key: _panelKey,
      height: height,
      margin: const EdgeInsets.only(top: 8, left: 46),
      decoration: BoxDecoration(
        color: AppTheme.card(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: _loading
          ? const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : count == 0
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _hint ?? LocaleHost.copyOf(context).noMatch,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: count,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final station = _suggestions[index];
                return InkWell(
                  onTap: () => _pick(station),
                  child: SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        const SizedBox(width: 14),
                        Icon(Far.building, size: 16, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            LocaleHost.copyOf(context).place(station.stationName),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, {this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          if (hint != null)
            Text(hint!, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Transit line row: solid colour badge, bold name, chevron.
class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: icon == null ? AppTheme.brand : AppTheme.field(Theme.of(context).brightness),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon ?? Fa.bus,
                size: 18,
                color: icon == null ? AppTheme.onColor : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Icon(Far.chevronRight, size: 14, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _BusMark extends StatelessWidget {
  const _BusMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppTheme.brand,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Fa.bus, size: 16, color: AppTheme.onColor),
    );
  }
}
