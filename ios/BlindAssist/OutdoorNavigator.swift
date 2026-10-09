import MapKit
import CoreLocation
import Combine

final class OutdoorNavigator: NSObject, ObservableObject, CLLocationManagerDelegate {
    var networkAllowed = false {
        didSet { if !networkAllowed { stop(); results = []; routeSteps = [] } }
    }
    @Published private(set) var message = "Choose an outdoor destination."
    @Published private(set) var results: [MKMapItem] = []
    @Published private(set) var routeSteps: [MKRoute.Step] = []
    @Published private(set) var location: CLLocation?
    @Published private(set) var heading: CLHeading?
    private let manager = CLLocationManager()
    private var search: MKLocalSearch?
    private var directions: MKDirections?
    override init() { super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyBest }
    func start() {
        manager.requestWhenInUseAuthorization(); manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() { manager.startUpdatingHeading() }
    }
    func stop() {
        manager.stopUpdatingLocation(); manager.stopUpdatingHeading()
        search?.cancel(); directions?.cancel(); search = nil; directions = nil
        location = nil; heading = nil; routeSteps = []
    }
    func search(_ query: String) {
        guard networkAllowed else { message = "Outdoor search needs internet access enabled in Settings."; return }
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        start(); search?.cancel()
        let request = MKLocalSearch.Request(); request.naturalLanguageQuery = query
        if let location { request.region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 3000, longitudinalMeters: 3000) }
        let search = MKLocalSearch(request: request); self.search = search; message = "Searching…"
        search.start { [weak self] response, error in
            DispatchQueue.main.async {
                guard let self, self.networkAllowed, self.search === search else { return }
                self.results = response?.mapItems ?? []
                self.message = error == nil ? "Select a destination." : "Destination search unavailable."
            }
        }
    }
    func plan(to item: MKMapItem) {
        guard networkAllowed else { message = "New outdoor routes need internet access enabled in Settings."; return }
        guard let location, Date().timeIntervalSince(location.timestamp) < 10,
              location.horizontalAccuracy >= 0, location.horizontalAccuracy < 30 else {
            message = "An accurate current GPS fix is required."; return
        }
        directions?.cancel(); routeSteps = []
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
        request.destination = item; request.transportType = .walking
        let directions = MKDirections(request: request); self.directions = directions
        directions.calculate { [weak self] response, error in
            DispatchQueue.main.async {
                guard let self, self.networkAllowed, self.directions === directions else { return }
                self.routeSteps = response?.routes.first?.steps.filter { !$0.instructions.isEmpty } ?? []
                self.message = error == nil ? "Walking route loaded. Confirm crossings independently." : "Route unavailable."
            }
        }
    }
    func bearing(to item: MKMapItem) -> (sector: Int, distance: Double)? {
        guard let location, let heading, location.horizontalAccuracy >= 0, location.horizontalAccuracy < 30,
              heading.headingAccuracy >= 0, heading.headingAccuracy < 25,
              Date().timeIntervalSince(location.timestamp) < 10,
              Date().timeIntervalSince(heading.timestamp) < 10 else { return nil }
        let target = CLLocation(latitude: item.placemark.coordinate.latitude, longitude: item.placemark.coordinate.longitude)
        let lat1 = location.coordinate.latitude * .pi / 180, lat2 = target.coordinate.latitude * .pi / 180
        let delta = (target.coordinate.longitude - location.coordinate.longitude) * .pi / 180
        let bearing = atan2(sin(delta) * cos(lat2), cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(delta)) * 180 / .pi
        let north = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
        let relative = (bearing - north + 720).truncatingRemainder(dividingBy: 360)
        return (Int((relative / 45).rounded()) % 8, location.distance(from: target))
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) { location = locations.last }
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) { heading = newHeading }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { message = "Location unavailable." }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted { message = "Location permission denied." }
    }
}
