import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geocoder/geocoder.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Maps Demo',
      initialRoute: '/',
      routes: {
        '/': (_) => Initial(),
        '/map': (_) => MapSample(),
      },
    );
  }
}

class Initial extends StatelessWidget {
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Google Map'), centerTitle: true),
      body: Center(
        child: RaisedButton(
          child: Icon(Icons.navigate_next),
          onPressed: () async {
            bool isGranted = await Geolocator().checkGeolocationPermissionStatus()==GeolocationStatus.granted;
            bool isEnabled = await Geolocator().isLocationServiceEnabled();
            if (isGranted && isEnabled) {
              Navigator.of(context).pushNamed('/map');
            } else {
              showGeneralDialog<void>(
                context: context,
                barrierDismissible: false,
                barrierColor: Colors.black.withOpacity(0.002),
                transitionDuration: Duration(milliseconds: 300),
                transitionBuilder: (context, animation, secondaryAnimation, Widget child) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                pageBuilder: (context, _, __) => Scaffold(
                  backgroundColor: Colors.black.withOpacity(0.5),
                  body: Center(child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 20.0),
                    padding: EdgeInsets.all(15.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      borderRadius: BorderRadius.all(Radius.circular(30)),
                    ),
                    child: Text(
                      'Se requiere el permiso de ubicación',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.title.copyWith(
                        color: Theme.of(context).colorScheme.onSecondary
                      ),
                    ),
                  )),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

class MapSample extends StatefulWidget {
  State createState() => _MapSampleState();
}
class _MapSampleState extends State<MapSample> {
  final _mapController = Completer<GoogleMapController>();
  final _markers = <MarkerId, Marker>{}; ///Marcadores disponibles dentro del mapa
  final _delayInPosition = Duration(seconds: 10); ///Retraso en actualizar [My position]
  StreamSubscription<Position> _location; ///Stream que permite actualizar [My position]
  LatLng _currentPosition; ///[My position]
  LatLng _targetPosition; ///Destino
  double _distanceInMeters;

  Future<void> _moveCamera({
    @required LatLng target,
    @required double zoom,
    double bearing = 0.0,
    double tilt = 0.0,
  }) async {
    CameraPosition camera = CameraPosition(
      target: target,
      zoom: zoom,
      bearing: bearing,
      tilt: tilt,
    );
    GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(camera));
  }

  Future<void> _moveMarker({ ///Mueve (o crea) el marcador dentro del mapa
    @required String markerId,
    @required LatLng position,
  }) async {
    assert(markerId!=null);
    assert(position!=null);

    final keyId = MarkerId(markerId); ///Identificador clave que diferencia cada marcador dentro del mapa
    final firstAdress = (await Geocoder.local.findAddressesFromCoordinates(Coordinates(position.latitude, position.longitude))).first;
    final markerDescription = firstAdress==null? '...' : firstAdress.addressLine;
    final positionMarker = Marker(
      markerId: keyId,
      position: position,
      infoWindow: InfoWindow(
        title: markerId,
        snippet: markerDescription,
        //onTap: () => setState(() => _markers.remove(keyId))
      ),
      /*onTap: () => _moveCamera(
				target: coordinates,
				zoom: 20.0,
			),*/
    );

    _markers[keyId] = positionMarker;
    setState(() {});
  }

  Future<void> _updateDistance({
    @required LatLng originPosition,
    @required LatLng targetPosition
  }) async {
    _distanceInMeters = await Geolocator().distanceBetween(
      originPosition.latitude, originPosition.longitude,
      targetPosition.latitude, targetPosition.longitude,
    );
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Google Map'), centerTitle: true),
      body: _currentPosition==null? Center(child: CircularProgressIndicator()) : GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: CameraPosition(
          target: _currentPosition,
          zoom: 20.0,
        ),
        onMapCreated: _mapController.complete,
        markers: Set<Marker>.of(_markers.values),
        onTap: (LatLng value) async {
          await _moveMarker(
            markerId: 'Target position',
            position:_targetPosition = value,
          );
          await _updateDistance(
            originPosition: _currentPosition,
            targetPosition: _targetPosition,
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          FloatingActionButton.extended(
            heroTag: null,
            label: Text('My position'),
            icon: Icon(Icons.location_on),
            onPressed: _currentPosition==null? null : () => _moveCamera(
              target: _currentPosition,
              zoom: 20.0,
            ),
          ),
          SizedBox(height: 7.5),
          FloatingActionButton.extended(
            heroTag: null,
            label: Text('Target position'),
            icon: Icon(Icons.location_searching),
            onPressed: _targetPosition==null? null : () => _moveCamera(
              target: _targetPosition,
              //bearing: 192.8334901395799,
              //tilt: 59.440717697143555,
              zoom: 20.0,
            ),
          ),
          SizedBox(height: 7.5),
          Container(
            width: 200.0,
            padding: EdgeInsets.all(5.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Text(
              _distanceInMeters==null? '...' : 'Distance : ${_distanceInMeters.toStringAsFixed(0)} meters',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSecondary
              ),
            ),
          ),
        ]
      ),
    );
  }

  void initState() {
    _location = Geolocator().getPositionStream(LocationOptions(timeInterval: _delayInPosition.inMilliseconds)).listen((Position position) async {
      if (position==null) return;
      _currentPosition = LatLng(position.latitude, position.longitude);

      if (_targetPosition!=null) {
        await _updateDistance(
          originPosition: _currentPosition,
          targetPosition: _targetPosition,
        );
      }
      await _moveMarker(
        markerId: 'My position',
        position: _currentPosition,
      );
      await _moveCamera(
				target: _currentPosition,
				zoom: 20.0,
			);
    });
    super.initState();
  }

  void dispose() {
    _location.cancel();
    super.dispose();
  }
}