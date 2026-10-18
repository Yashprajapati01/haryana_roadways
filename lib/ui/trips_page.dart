import 'package:flutter/material.dart';
import 'fa.dart';

import '../data/cache.dart';
import '../locate/live_client.dart';
import '../locate/snap.dart';
import '../timetable/hr_api.dart';
import '../timetable/models.dart';
import 'app_theme.dart';
import 'copy.dart';
import 'trip_page.dart';

class TripsPage extends StatefulWidget {
  const TripsPage({
    super.key,
    required this.api,
    required this.boarding,
    required this.destination,
    this.cache,
  });

  final HrApi api;
  final Station boarding;
  final Station destination;
  final AppCache? cache;

  @override
  State<TripsPage> createState() => _TripsPageState();
}

enum _LiveKind { seen, none, down, failed }

class _Listed {
  const _Listed({required this.stops, required this.kind, this.hit});

  final List<RouteStop> stops;
  final _LiveKind kind;
  final SnapHit? hit;
}

class _TripsPageState extends State<TripsPage> {
  late Future<List<TripStop>> _trips;
  final _places = <int, Future<_Listed>>{};
  final _live = LiveClient();

  Future<_Listed> _placeFor(int dutyId) {
    return _places.putIfAbsent(dutyId, () async {
      try {
        final day = dayKey(DateTime.now());
        final stopsFuture = _stopsFor(dutyId, day);
        final liveFuture = _live.look(dutyId, day, timeout: const Duration(seconds: 2));
        final stops = await _located(await stopsFuture);
        final look = await liveFuture;
        final fix = look.fix;
        if (fix != null) {
          return _Listed(
            stops: stops,
            kind: _LiveKind.seen,
            hit: placeAtDistance(stops, fix.distanceM),
          );
        }
        return _Listed(
          stops: stops,
          kind: look.reached ? _LiveKind.none : _LiveKind.down,
        );
      } catch (_) {
        return const _Listed(stops: [], kind: _LiveKind.failed);
      }
    });
  }

  Future<List<RouteStop>> _stopsFor(int dutyId, String day) async {
    final cached = await widget.cache?.duty(dutyId, day);
    if (cached != null && cached.isNotEmpty) return cached;
    final rows = await widget.api.dutyStops(dutyId);
    final stops = [
      for (final row in rows)
        RouteStop(srNo: row.srNo, name: row.stopName, time: row.tripTime),
    ];
    await widget.cache?.saveDuty(dutyId, day, stops);
    return stops;
  }

  Future<List<RouteStop>> _located(List<RouteStop> stops) async {
    final cache = widget.cache;
    if (cache == null) return stops;
    final located = <RouteStop>[];
    for (final stop in stops) {
      final geo = await cache.geo(stop.name);
      if (geo == null || geo.missed || geo.lat == null || geo.lng == null) {
        located.add(stop);
      } else {
        located.add(
          RouteStop(
            srNo: stop.srNo,
            name: stop.name,
            time: stop.time,
            lat: geo.lat,
            lng: geo.lng,
          ),
        );
      }
    }
    return located;
  }

  @override
  void initState() {
    super.initState();
    _trips = widget.api.trips(
      boarding: [widget.boarding],
      destination: [widget.destination],
    );
  }

  @override
  Widget build(BuildContext context) {
    final from = widget.boarding.stationName;
    final to = widget.destination.stationName;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${LocaleHost.copyOf(context).place(from)} → ${LocaleHost.copyOf(context).place(to)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        actions: const [LanguageButton(), ThemeModeButton()],
      ),
      body: FutureBuilder<List<TripStop>>(
        future: _trips,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _ShimmerList();
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  LocaleHost.copyOf(context).trouble(snapshot.error!),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final trips = snapshot.data ?? const <TripStop>[];
          if (trips.isEmpty) {
            return Center(child: Text(LocaleHost.copyOf(context).noBuses));
          }
          final text = Theme.of(context).textTheme;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            itemCount: trips.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Text(
                  LocaleHost.copyOf(context).busCount(trips.length),
                  style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                );
              }
              final trip = trips[index - 1];
              return _TripTicket(
                trip: trip,
                where: _placeFor(trip.dutyID),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TripPage(
                        api: widget.api,
                        trip: trip,
                        cache: widget.cache,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Transit colours a line's card by its state; one hue per card, white type.
Color _cardColor(RideStatus? status) {
  return switch (status) {
    RideStatus.onRoad || RideStatus.seen => AppTheme.go,
    RideStatus.arrived => AppTheme.stopped,
    RideStatus.notStarted || null => AppTheme.brand,
  };
}

class _TripTicket extends StatelessWidget {
  const _TripTicket({required this.trip, required this.where, required this.onTap});

  final TripStop trip;
  final Future<_Listed> where;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final copy = LocaleHost.copyOf(context);
    final text = Theme.of(context).textTheme;
    final vehicle = trip.vehicleNumber;
    const ink = AppTheme.onColor;
    const soft = Color(0xD9FFFFFF);
    return FutureBuilder<_Listed>(
      future: where,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _ShimmerCard();
        }
        final listed = snapshot.data;
        final ride = listed == null ? null : _ride(listed, copy);
        final leg = _leg(listed?.stops ?? const [], copy);
        final live = _liveLine(listed, copy);
        final meta = [
          leg.span,
          if (vehicle != null) copy.place(vehicle),
          if (listed != null && listed.stops.length > 1)
            copy.stopCount((ride?.toIndex ?? 0) + 1, listed.stops.length),
        ].join(' · ');
        return Material(
          color: _cardColor(ride?.status),
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Badge(copy.place(trip.depotName)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          ride?.title ?? copy.checking,
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall?.copyWith(color: ink, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        leg.depart,
                        style: text.displaySmall?.copyWith(
                          color: ink,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Fa.arrowRight, size: 16, color: soft),
                      const SizedBox(width: 12),
                      Text(
                        leg.arrive,
                        style: text.headlineSmall?.copyWith(color: soft, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${leg.from} → ${leg.to}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(color: ink, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(meta, style: text.bodySmall?.copyWith(color: soft)),
                  if (ride != null && ride.detail.isNotEmpty)
                    Text(copy.place(ride.detail), style: text.bodySmall?.copyWith(color: soft)),
                  if (live != null) Text(live, style: text.bodySmall?.copyWith(color: soft)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  RidePlace _ride(_Listed listed, Copy copy) {
    final now = DateTime.now();
    final words = copy.ride;
    final hit = listed.hit;
    if (listed.kind == _LiveKind.seen && hit != null) {
      return rideSeen(listed.stops, hit, now, words: words);
    }
    final clock = rideByClock(listed.stops, now, words: words);
    if (listed.kind == _LiveKind.seen) {
      return RidePlace(
        status: RideStatus.seen,
        fromIndex: clock.fromIndex,
        toIndex: clock.toIndex,
        fraction: clock.fraction,
        title: words.seen,
        detail: clock.detail,
      );
    }
    return clock;
  }

  String? _liveLine(_Listed? listed, Copy copy) {
    if (listed == null || listed.kind == _LiveKind.seen) return null;
    return switch (listed.kind) {
      _LiveKind.none => copy.noRider,
      _LiveKind.down => null,
      _LiveKind.failed => copy.couldNotPlace,
      _LiveKind.seen => null,
    };
  }

  _Leg _leg(List<RouteStop> stops, Copy copy) {
    if (stops.isEmpty) {
      return _Leg(
        depart: clockLabel(trip.tripTime),
        arrive: '-',
        span: '-',
        from: copy.place(trip.boardingStationName),
        to: copy.place(trip.destinationStationName),
      );
    }
    var fromIndex = _indexOf(stops, trip.boardingStationName);
    var toIndex = _indexOf(stops, trip.destinationStationName);
    if (fromIndex < 0) fromIndex = 0;
    if (toIndex < 0) toIndex = stops.length - 1;
    final from = stops[fromIndex];
    final to = stops[toIndex];
    return _Leg(
      depart: clockLabel(from.time),
      arrive: clockLabel(to.time),
      span: copy.span(to.time.difference(from.time).abs()),
      from: copy.place(from.name),
      to: copy.place(to.name),
    );
  }

  int _indexOf(List<RouteStop> stops, String name) {
    final needle = name.toLowerCase();
    return stops.indexWhere((stop) => stop.name.toLowerCase() == needle);
  }
}

class _Leg {
  const _Leg({
    required this.depart,
    required this.arrive,
    required this.span,
    required this.from,
    required this.to,
  });

  final String depart;
  final String arrive;
  final String span;
  final String from;
  final String to;
}


/// Transit route badge: translucent white pill on the coloured card.
class _Badge extends StatelessWidget {
  const _Badge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x33FFFFFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Fa.bus, size: 13, color: AppTheme.onColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.onColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Grey card swept by a lighter band. Shown until that bus's stops have loaded.
class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard();

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF1F232B) : const Color(0xFFE5E7EB);
    final band = dark ? const Color(0xFF343B48) : const Color(0xFFF8F9FB);
    return AnimatedBuilder(
      animation: _sweep,
      builder: (context, _) {
        final t = _sweep.value;
        return Container(
          height: 128,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment(-1.6 + 3.2 * t, 0),
              end: Alignment(-0.2 + 3.2 * t, 0),
              colors: [base, band, base],
            ),
          ),
        );
      },
    );
  }
}

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => const _ShimmerCard(),
    );
  }
}
