import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:location_tracker/constants.dart';

class GetLocation extends StatefulWidget {
  const GetLocation({super.key});

  @override
  State<GetLocation> createState() => _GetLocationState();
}

class _GetLocationState extends State<GetLocation> {
  TextEditingController _latitudeController = TextEditingController();
  TextEditingController _longitudeController = TextEditingController();
  static const LatLng _latLng = LatLng(37.4223, -122.0848);
  static const LatLng flex = LatLng(37.3346, -122.0090);
  final Completer<GoogleMapController> _mapController =
      Completer<GoogleMapController>();
  Location _locationController = new Location();
  LatLng? currentP = null;
  Map<PolylineId, Polyline> polylines = {};

  @override
  void initState() {
    super.initState();
    getLocation().then(
      (_) => {
        getPolylinePoints().then(
          (coordinates) => {generatePolylineFromPoints(coordinates)},
        ),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: currentP == null
          ? const Center(
              child: Text('Loading'),
            )
          : GoogleMap(
              myLocationEnabled: true,
              compassEnabled: true,
              zoomControlsEnabled: true,
              onMapCreated: ((GoogleMapController controller) =>
                  _mapController.complete(controller)),
              initialCameraPosition:
                  const CameraPosition(target: _latLng, zoom: 13),
              markers: {
                Marker(
                    onTap: () {
                      _showLocationEditDialog();
                    },
                    markerId: const MarkerId('current location'),
                    icon: BitmapDescriptor.defaultMarker,
                    position: currentP!),
                Marker(
                    onTap: () {
                      _showLocationEditDialog();
                    },
                    markerId: MarkerId('source location'),
                    icon: BitmapDescriptor.defaultMarker,
                    position: flex),
                Marker(
                    onTap: () {
                      _showLocationEditDialog();
                    },
                    markerId: MarkerId('destination'),
                    icon: BitmapDescriptor.defaultMarker,
                    position: _latLng),
              },
              polylines: Set<Polyline>.of(polylines.values),
            ),
      floatingActionButton: Row(
        children: [
          const SizedBox(
            width: 22,
          ),
          FloatingActionButton(
            backgroundColor: Colors.blue,
            onPressed: () {
              setState(() {
                getPolylinePoints().then(
                    (coordinates) => generatePolylineFromPoints(coordinates));
              });
            },
            child: const Icon(Icons.assistant_navigation),
          ),
          const SizedBox(
            width: 12,
          ),
          FloatingActionButton(
            backgroundColor: Colors.red,
            onPressed: () {
              setState(() {
                stopRoute();
              });
            },
            child: const Icon(
              Icons.stop,
            ),
          )
        ],
      ),
    );
  }

  Future<void> cameraPosition(LatLng pos) async {
    final GoogleMapController controller = await _mapController.future;
    CameraPosition _newCameraPosition = CameraPosition(target: pos, zoom: 13);
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(_newCameraPosition),
    );
  }

  Future<void> stopRoute() async {}

  void generatePolylineFromPoints(List<LatLng> polylineCoordinates) async {
    PolylineId id = const PolylineId('poly');
    Polyline polyline = Polyline(
        polylineId: id,
        color: Colors.blueAccent,
        points: polylineCoordinates,
        width: 8);
    setState(() {
      polylines[id] = polyline;
    });
  }

  Future<void> _showLocationEditDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Location'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _latitudeController,
                keyboardType: TextInputType.name,
                decoration: InputDecoration(labelText: 'Latitude'),
              ),
              TextField(
                controller: _longitudeController,
                keyboardType: TextInputType.name,
                decoration: InputDecoration(labelText: 'Longitude'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                double latitude =
                    double.tryParse(_latitudeController.text) ?? 0.0;
                double longitude =
                    double.tryParse(_longitudeController.text) ?? 0.0;
                setState(() {
                  currentP = LatLng(latitude, longitude);
                });
                Navigator.of(context).pop();
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<List<LatLng>> getPolylinePoints() async {
    List<LatLng> polylineCoordinates = [];
    PolylinePoints polylinePoints = PolylinePoints();
    PolylineResult polylineResult =
        await polylinePoints.getRouteBetweenCoordinates(
            GOOGLE_MAP_API,
            PointLatLng(currentP!.latitude, currentP!.longitude),
            PointLatLng(_latLng.latitude, _latLng.longitude),
            travelMode: TravelMode.driving);
    if (polylineResult.points.isNotEmpty) {
      polylineResult.points.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
    } else {
      print(polylineResult.errorMessage);
    }
    return polylineCoordinates;
  }

  Future<void> getLocation() async {
    bool _serviceEnabled;
    PermissionStatus permissionGranted;
    _serviceEnabled = await _locationController.serviceEnabled();
    if (_serviceEnabled) {
      _serviceEnabled = await _locationController.requestService();
    } else {
      return;
    }

    permissionGranted = await _locationController.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _locationController.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }
    _locationController.onLocationChanged
        .listen((LocationData currentLocation) {
      if (currentLocation.latitude != null &&
          currentLocation.longitude != null) {
        setState(() {
          currentP =
              LatLng(currentLocation.latitude!, currentLocation.longitude!);
         cameraPosition(currentP!);
          print(currentP);
        });
      }
    });
  }
}
