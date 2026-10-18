import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'fa.dart';
import 'package:geolocator/geolocator.dart';

import '../data/cache.dart';
import '../locate/cell_table.dart';
import '../locate/geocode.dart';
import '../locate/live_client.dart';
import '../locate/on_bus.dart';
import '../locate/snap.dart';
import '../timetable/hr_api.dart';
import '../timetable/models.dart';
import 'app_theme.dart';
import 'copy.dart';

class TripPage extends StatefulWidget {
  const TripPage({
    super.key,
    required this.api,
    required this.trip,
    this.cache,
    this.geocoder,
    this.live,
    this.cells,
    this.tracker,
  });

  final HrApi api;
  final TripStop trip;
  final AppCache? cache;
  final Geocoder? geocoder;
  final LiveClient? live;
  final CellReader? cells;
  final OnBusTracker? tracker;

  @override
  State<TripPage> createState() => _TripPageState();
}

class _TripPageState extends State<TripPage> {
  late final Geocoder _geocoder = widget.geocoder ?? Geocoder();
  late final LiveClient _live = widget.live ?? LiveClient();
  late final CellReader _cells = widget.cells ?? CellReader();
  late final OnBusTracker _tracker = widget.tracker ?? OnBusTracker();
  final _table = CellTable();
  final _loadedCells = <CellKey>{};

  List<RouteStop> _stops = const [];
  bool _loading = true;
  String? _error;
  bool _onBus = false;
  ShareMode _mode = ShareMode.tower;
  RideBlock? _block;
  String? _notice;
  SnapHit? _own;
  SeenFix? _seen;
  bool _liveChecked = false;
  bool _liveUp = false;
  bool _showAll = false;
  String _clientId = '';
  Timer? _timer;
  Timer? _towerTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _towerTimer?.cancel();
    _tracker.stop();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final day = dayKey(DateTime.now());
      final cached = await widget.cache?.duty(widget.trip.dutyID, day);
      final List<RouteStop> stops;
      if (cached != null && cached.isNotEmpty) {
        stops = cached;
      } else {
        final rows = await widget.api.dutyStops(widget.trip.dutyID);
        stops = [
          for (final row in rows)
            RouteStop(srNo: row.srNo, name: row.stopName, time: row.tripTime),
        ];
        await widget.cache?.saveDuty(widget.trip.dutyID, day, stops);
      }
      final id = await widget.cache?.clientId() ?? _fallbackId();
      if (!mounted) return;
      setState(() {
        _stops = stops;
        _clientId = id;
        _loading = false;
      });
      await _geocodeMissing();
      await _tick();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  String _fallbackId() {
    final random = Random();
    return List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join();
  }

  Future<void> _geocodeMissing() async {
    for (var i = 0; i < _stops.length; i++) {
      if (!mounted) return;
      final name = _stops[i].name;
      final cached = await widget.cache?.geo(name);
      if (cached != null) {
        if (!cached.missed && cached.lat != null && cached.lng != null) {
          _setPoint(i, cached.lat!, cached.lng!);
        }
        continue;
      }
      final point = await _geocoder.lookup(name);
      await widget.cache?.saveGeo(
        name,
        lat: point?.lat,
        lng: point?.lng,
        missed: point == null,
      );
      if (point != null) _setPoint(i, point.lat, point.lng);
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  void _setPoint(int index, double lat, double lng) {
    final stop = _stops[index];
    setState(() {
      _stops = [
        for (var i = 0; i < _stops.length; i++)
          if (i == index)
            RouteStop(
              srNo: stop.srNo,
              name: stop.name,
              time: stop.time,
              lat: lat,
              lng: lng,
            )
          else
            _stops[i],
      ];
    });
  }

  Future<void> _tick() async {
    final look = await _live.look(widget.trip.dutyID, dayKey(DateTime.now()));
    if (!mounted) return;
    setState(() {
      _seen = look.fix;
      _liveChecked = true;
      _liveUp = look.reached;
    });
  }

  String? get _liveLine {
    if (_seen != null || _onBus || !_liveChecked) return null;
    final copy = LocaleHost.copyOf(context);
    return _liveUp ? copy.noRider : copy.liveDown;
  }

  List<int> _visible(_Place place) {
    if (_showAll || _stops.isEmpty) {
      return [for (var i = 0; i < _stops.length; i++) i];
    }
    final indexes = <int>{place.fromIndex, place.toIndex};
    if (place.fromIndex > 0) indexes.add(place.fromIndex - 1);
    if (place.toIndex + 1 < _stops.length) indexes.add(place.toIndex + 1);
    final visible = indexes.toList()..sort();
    return visible;
  }

  Future<void> _toggle(bool on) async {
    if (!on) {
      _towerTimer?.cancel();
      _towerTimer = null;
      await _tracker.stop();
      if (!mounted) return;
      setState(() {
        _onBus = false;
        _own = null;
        _block = null;
        _notice = null;
      });
      return;
    }
    final copy = LocaleHost.copyOf(context);
    final mode = await _askShare(copy);
    if (!mounted || mode == null) return;
    try {
      await _cells.prepare();
      if (!mounted) return;
      setState(() => _mode = mode);
      if (mode == ShareMode.gps) {
        await _tracker.start(
          _onGps,
          noticeTitle: copy.sharingGps,
          noticeText: copy.sharingHint,
          cells: _cells,
        );
      } else {
        await _tracker.permit(_cells);
      }
      if (!mounted) return;
      setState(() {
        _mode = mode;
        _onBus = true;
        _block = null;
        _notice = null;
      });
      if (mode == ShareMode.tower) {
        await _onTower();
        _towerTimer = Timer.periodic(const Duration(seconds: 20), (_) => _onTower());
      }
    } catch (error) {
      _towerTimer?.cancel();
      _towerTimer = null;
      await _tracker.stop();
      if (!mounted) return;
      setState(() {
        _onBus = false;
        _block = error is RideBlocked ? error.block : RideBlock.failed;
      });
    }
  }

  /// GPS mode. A good fix also teaches the current tower, but the dot stays on GPS.
  Future<void> _onGps(Position position) async {
    if (_mode != ShareMode.gps) return;
    final cell = await _cells.serving();
    if (cell != null) await _remember(cell);
    SnapHit? hit;
    final lat = position.latitude;
    final lng = position.longitude;
    if (position.accuracy <= 80) {
      if (cell != null) {
        _table.learn(cell, lat, lng);
        final samples = _table.samplesOf(cell);
        await widget.cache?.saveTower(cell, samples);
      }
      hit = snapToRoute(_stops, lat, lng, maxCrossTrackM: gpsCrossTrackM);
    }
    if (!mounted || _mode != ShareMode.gps) return;
    setState(() => _own = hit);
    if (hit == null || _clientId.isEmpty) return;
    await _live.upload(
      clientId: _clientId,
      dutyId: widget.trip.dutyID,
      date: dayKey(DateTime.now()),
      distanceM: hit.distanceM,
      lat: lat,
      lng: lng,
      source: 'gps',
      confirmed: true,
    );
    await _tick();
  }

  /// Tower mode. No GPS stream. A tower only places the bus after a GPS ride taught it.
  Future<void> _onTower() async {
    if (_mode != ShareMode.tower || !_onBus) return;
    final cell = await _cells.serving();
    if (cell != null) await _remember(cell);
    SnapHit? hit;
    var lat = 0.0;
    var lng = 0.0;
    final tower = cell == null ? null : _table.locate(cell);
    if (tower != null) {
      hit = snapToRoute(_stops, tower.lat, tower.lng, maxCrossTrackM: cellCrossTrackM);
      lat = tower.lat;
      lng = tower.lng;
    }
    if (!mounted || _mode != ShareMode.tower || !_onBus) return;
    setState(() {
      _own = hit;
      _notice = hit == null ? LocaleHost.copyOf(context).towerUnknown : null;
    });
    if (hit == null || _clientId.isEmpty) return;
    await _live.upload(
      clientId: _clientId,
      dutyId: widget.trip.dutyID,
      date: dayKey(DateTime.now()),
      distanceM: hit.distanceM,
      lat: lat,
      lng: lng,
      source: 'cell',
      confirmed: true,
    );
    await _tick();
  }

  Future<void> _remember(CellKey key) async {
    if (_loadedCells.contains(key)) return;
    _loadedCells.add(key);
    final samples = await widget.cache?.towerSamples(key) ?? const <LatLng>[];
    for (final sample in samples) {
      _table.learn(key, sample.lat, sample.lng);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          LocaleHost.copyOf(context).place(widget.trip.tripName),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        actions: const [LanguageButton(), ThemeModeButton()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(LocaleHost.copyOf(context).trouble(_error!)))
          : _body(),
    );
  }

  Widget _body() {
    final place = _place();
    final copy = LocaleHost.copyOf(context);
    final visible = _visible(place);
    final tint = _phaseColor(place.phase);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: _StatusBanner(place: place, color: tint, depot: copy.place(widget.trip.depotName)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => setState(() => _showAll = !_showAll),
              child: Text(
                _showAll ? copy.nearbyStops : copy.allStops(_stops.length),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 20, 96),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final stopIndex = visible[index];
              return _StopRow(
                stop: _stops[stopIndex],
                index: stopIndex,
                last: stopIndex == _stops.length - 1,
                place: place,
                color: tint,
              );
            },
          ),
        ),
        _shareBar(),
      ],
    );
  }

  static Color _phaseColor(_Phase phase) => switch (phase) {
    _Phase.departs => AppTheme.brand,
    _Phase.riding || _Phase.here => AppTheme.go,
    _Phase.arrived => AppTheme.stopped,
  };

  /// Tower is the default. GPS is the higher-accuracy choice.
  Future<ShareMode?> _askShare(Copy copy) {
    return showDialog<ShareMode>(
      context: context,
      builder: (context) {
        final text = Theme.of(context).textTheme;
        return AlertDialog(
          title: Text(copy.shareAskTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(copy.shareAskBody),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, ShareMode.tower),
                icon: const Icon(Fa.tower, size: 16),
                label: Text(copy.useTower),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () => Navigator.pop(context, ShareMode.gps),
                icon: const Icon(Fa.locationArrow, size: 16),
                label: Text(copy.useGpsAccurate, style: text.titleSmall),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Transit's GO pill: one big green button, or a green bar while sharing.
  Widget _shareBar() {
    final copy = LocaleHost.copyOf(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final problem = switch (_block) {
      RideBlock.off => copy.locationOff,
      RideBlock.denied => copy.locationDenied,
      RideBlock.failed => copy.couldNotPlace,
      null => null,
    };
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (problem != null || _notice != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  problem ?? _notice!,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(
                    color: problem != null ? scheme.error : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (_onBus)
              Material(
                color: AppTheme.go,
                shape: const StadiumBorder(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 8, 6),
                  child: Row(
                    children: [
                      Icon(
                        _mode == ShareMode.gps ? Fa.locationArrow : Fa.tower,
                        size: 18,
                        color: AppTheme.onColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _mode == ShareMode.gps ? copy.sharingGps : copy.sharingTower,
                          style: text.titleMedium?.copyWith(
                            color: AppTheme.onColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.onColor,
                          minimumSize: const Size(48, 44),
                        ),
                        onPressed: () => _toggle(false),
                        icon: const Icon(Far.xmark, size: 16),
                        label: Text(copy.stopSharing),
                      ),
                    ],
                  ),
                ),
              )
            else
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.go, elevation: 6),
                onPressed: () => _toggle(true),
                icon: const Icon(Fa.bus, size: 18),
                label: Text(copy.onThisBus),
              ),
          ],
        ),
      ),
    );
  }

  _Place _place() {
    final seen = _seen;
    if (seen != null) {
      final hit = placeAtDistance(_stops, seen.distanceM);
      if (hit != null) {
        return _fromRide(
          rideSeen(_stops, hit, DateTime.now(), words: LocaleHost.copyOf(context).ride),
          liveLine: null,
        );
      }
      final words = LocaleHost.copyOf(context).ride;
      final clock = rideByClock(_stops, DateTime.now(), words: words);
      return _fromRide(
        RidePlace(
          status: RideStatus.seen,
          fromIndex: clock.fromIndex,
          toIndex: clock.toIndex,
          fraction: clock.fraction,
          title: words.seen,
          detail: clock.detail,
        ),
        liveLine: null,
      );
    }
    final own = _own;
    if (_onBus && own != null) {
      return _Place(
        fromIndex: own.fromIndex,
        toIndex: own.toIndex,
        fraction: own.fraction,
        phase: own.fromIndex == own.toIndex ? _Phase.here : _Phase.riding,
        title: LocaleHost.copyOf(context).yourPosition,
        detail: _detail(own.fromIndex, own.toIndex, own.fraction, own),
        progress: _progress(own.fromIndex, own.toIndex, own.fraction, _Phase.riding),
        liveLine: null,
      );
    }
    return _fromRide(
      rideByClock(_stops, DateTime.now(), words: LocaleHost.copyOf(context).ride),
      liveLine: _liveLine,
    );
  }

  _Place _fromRide(RidePlace ride, {required String? liveLine}) {
    final phase = switch (ride.status) {
      RideStatus.notStarted => _Phase.departs,
      RideStatus.arrived => _Phase.arrived,
      RideStatus.seen when ride.fromIndex == ride.toIndex => _Phase.here,
      _ => _Phase.riding,
    };
    return _Place(
      fromIndex: ride.fromIndex,
      toIndex: ride.toIndex,
      fraction: ride.fraction,
      phase: phase,
      title: ride.title,
      detail: ride.detail,
      progress: ride.progress(_stops.length),
      liveLine: liveLine,
    );
  }

  double _progress(int from, int to, double fraction, _Phase phase) {
    final count = _stops.length;
    if (count <= 1) return phase == _Phase.arrived ? 1 : 0;
    if (phase == _Phase.arrived) return 1;
    if (phase == _Phase.departs) return 0;
    final along = from + (from == to ? 0 : fraction);
    return (along / (count - 1)).clamp(0.0, 1.0);
  }

  String _detail(int from, int to, double fraction, SnapHit? hit) {
    final words = LocaleHost.copyOf(context).ride;
    if (_stops.isEmpty) return '';
    final start = _stops[from];
    final end = _stops[to];
    if (from == to) return words.fill(words.atStop, {'name': start.name});
    final remain = _remainingKm(start, end, fraction);
    final gap = remain == null ? '' : ' · $remain';
    final late = hit == null ? '' : _late(hit);
    return '${words.fill(words.leftNext, {'name': start.name, 'next': end.name})}$gap$late';
  }

  String _late(SnapHit hit) {
    final words = LocaleHost.copyOf(context).ride;
    final minutes = minutesLate(_stops, hit, DateTime.now());
    if (minutes.abs() < 1) return '';
    if (minutes > 0) return ' · ${words.fill(words.late, {'mins': '$minutes'})}';
    return ' · ${words.fill(words.early, {'mins': '${-minutes}'})}';
  }

  String? _remainingKm(RouteStop start, RouteStop end, double fraction) {
    if (!start.located || !end.located) return null;
    final meters =
        metersBetween(start.lat!, start.lng!, end.lat!, end.lng!) * (1 - fraction);
    final km = meters / 1000;
    return LocaleHost.copyOf(context).distance(km);
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.index,
    required this.last,
    required this.place,
    required this.color,
  });

  final RouteStop stop;
  final int index;
  final bool last;
  final _Place place;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final onFrom = index == place.fromIndex;
    final onTo = index == place.toIndex;
    // Green only behind the bus. The stop it is heading to stays hollow.
    final reached =
        index < place.fromIndex || (onFrom && place.phase != _Phase.departs);
    final lineAbove = reached ? color : scheme.outline;
    final lineBelow = index < place.fromIndex ? color : scheme.outline;
    final next = place.phase == _Phase.riding && onTo && place.fromIndex != place.toIndex;
    final copy = LocaleHost.copyOf(context);
    final mark = switch (place.phase) {
      _Phase.riding when onTo => copy.next,
      _Phase.riding when onFrom => copy.left,
      _Phase.arrived when onFrom => copy.ride.arrived,
      _Phase.departs when onFrom => copy.departs,
      _Phase.here when onFrom => copy.here,
      _ => null,
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 4,
                  height: 8,
                  color: index == 0 ? const Color(0x00000000) : lineAbove,
                ),
                next
                    ? _PulseDot(color: color)
                    : Container(
                        width: mark != null ? 18 : 14,
                        height: mark != null ? 18 : 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: reached ? color : scheme.surface,
                          border: Border.all(
                            color: reached ? color : scheme.outline,
                            width: 3,
                          ),
                        ),
                      ),
                Expanded(
                  child: Container(
                    width: 4,
                    color: last ? const Color(0x00000000) : lineBelow,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      clockLabel(stop.time),
                      style: text.titleMedium?.copyWith(
                        color: onFrom ? color : scheme.onSurfaceVariant,
                        fontWeight: onFrom ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LocaleHost.copyOf(context).place(stop.name),
                          style: text.titleMedium?.copyWith(
                            fontWeight: onFrom ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                        if (mark != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              mark,
                              style: text.labelLarge?.copyWith(
                                color: color,
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
          ),
        ],
      ),
    );
  }
}

/// Ring on the stop the bus is heading to. The halo breathes in the route colour.
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});

  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      width: 16,
      height: 16,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final t = reduce ? 1.0 : _pulse.value;
          return OverflowBox(
            maxWidth: 64,
            maxHeight: 64,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 16 + 36 * t,
                  height: 16 + 36 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.5 * (1 - t)),
                  ),
                ),
                Transform.scale(
                  scale: 0.75 + 0.4 * t,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color,
                      border: Border.all(color: const Color(0xFFFFFFFF), width: 2),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Transit ETA card: one solid colour, white type, the state as the headline.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.place, required this.color, required this.depot});

  final _Place place;
  final Color color;
  final String depot;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final copy = LocaleHost.copyOf(context);
    final seen = place.title == copy.ride.seen;
    final yours = place.title == copy.yourPosition;
    final icon = seen
        ? Fa.users
        : yours
        ? Fa.locationArrow
        : Fa.clock;
    const ink = AppTheme.onColor;
    const soft = Color(0xD9FFFFFF);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: soft),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    depot,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge?.copyWith(color: soft, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              place.title,
              style: text.displaySmall?.copyWith(color: ink, fontWeight: FontWeight.w800, height: 1.05),
            ),
            const SizedBox(height: 6),
            Text(copy.place(place.detail), style: text.titleSmall?.copyWith(color: ink)),
            if (place.liveLine != null)
              Text(place.liveLine!, style: text.bodySmall?.copyWith(color: soft)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: place.progress,
                minHeight: 6,
                color: ink,
                backgroundColor: const Color(0x40FFFFFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum ShareMode { gps, tower }

enum _Phase { departs, riding, arrived, here }

class _Place {
  const _Place({
    required this.fromIndex,
    required this.toIndex,
    required this.fraction,
    required this.phase,
    required this.title,
    required this.detail,
    required this.progress,
    required this.liveLine,
  });

  final int fromIndex;
  final int toIndex;
  final double fraction;
  final _Phase phase;
  final String title;
  final String detail;
  final double progress;
  final String? liveLine;
}
