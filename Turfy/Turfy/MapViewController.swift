//
//  SecondViewController.swift
//  Turfy
//
//  Created by Lawrence Dawson on 25/10/2016.
//  Copyright © 2016 Lawrence Dawson. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import Firebase

struct PreferencesKeys {
    static let savedItems = "savedItems"
}

struct Coordinates {
	static var latitude : Double = 0
	static var longitude : Double = 0
}

class MapViewController: UIViewController {

    let regionRadius: CLLocationDistance = 500
    
    var searchController:UISearchController!
    var annotation:MKAnnotation!
    var localSearchRequest:MKLocalSearchRequest!
    var localSearch:MKLocalSearch!
    var localSearchResponse:MKLocalSearchResponse!
    var error:NSError!
    var pointAnnotation:MKPointAnnotation!
    var pinAnnotationView:MKPinAnnotationView!
    
    var messages: [Message] = []

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let composeViewController = segue.destination as! ComposeViewController
        composeViewController.latitude = self.map.centerCoordinate.latitude
        composeViewController.longitude = self.map.centerCoordinate.longitude
		Coordinates.latitude = self.map.centerCoordinate.latitude
		Coordinates.longitude = self.map.centerCoordinate.longitude
    }

	
	//DB stuff below needs extraction
	let ref = FIRDatabase.database().reference().child("messages")
	let inboxRef = FIRDatabase.database().reference().child("messages").child((FIRAuth.auth()?.currentUser?.uid)!)
	
    //let sampleMessage : Message = Message(id: "test message", sender: (FIRAuth.auth()?.currentUser?.uid)!, recipient: "zwcxlPQwDAhYIxX9k4hDn77LvQY2", text: "Hey Johnny!", latitude: 50.00, longitude: 0.00, radius: 500, eventType: "On Entry", status: "Sent")

	//DB stuff above needs extraction
	
    @IBOutlet weak var address: UILabel!
    @IBOutlet weak var map: MKMapView!
    @IBAction func showSearchBar(_ sender: AnyObject) {
        searchController = UISearchController(searchResultsController: nil)
        searchController.hidesNavigationBarDuringPresentation = false
        self.searchController.searchBar.delegate = self
        present(searchController, animated: true, completion: nil)
    }
    
    var geoCoder: CLGeocoder!
    let locationManager = CLLocationManager()
    var previousAddress: String!
    func centerMapOnLocation(location: CLLocation) {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, regionRadius * 2.0, regionRadius * 2.0)
        map.setRegion(coordinateRegion, animated: true)
    }

    

    
    func geoCode(location : CLLocation!){
        /* Only one reverse geocoding can be in progress at a time hence we need to cancel existing
         one if we are getting location updates */
        geoCoder.cancelGeocode()
        geoCoder.reverseGeocodeLocation(location, completionHandler: {(data, error) -> Void in
            guard let placeMarks = data as [CLPlacemark]! else
            {return}
            let loc: CLPlacemark = placeMarks[0]
            let addressDict : [NSString:NSObject] = loc.addressDictionary as! [NSString: NSObject]
            let addrList = addressDict["FormattedAddressLines"] as! [String]
            let address = addrList.joined(separator: ", ")
            print(address)
            self.address.text = address
            self.previousAddress = address
        })
        
    }

	override func viewDidLoad() {
        
		super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        locationManager.requestLocation()
        geoCoder = CLGeocoder()
        messages = []
        loadAllMessages()
        
        let initialLocation = CLLocation(latitude: 51.508182, longitude: -0.126771)
        centerMapOnLocation(location: initialLocation)
        map.delegate = self
        let pin = Pin(title: "London", locationName: "Current Location", discipline: "Location", coordinate: CLLocationCoordinate2D (latitude: 51.508182, longitude: -0.126771))
        map.addAnnotation(pin)
		
		// DB Stuff below, needs extraction
		
		inboxRef.observe(.childAdded, with: { (snapshot) -> Void in
			let message = Message(snapshot: snapshot)
			if message.status.rawValue != "Sent" {
				self.messages.append(message)
            } else {
                message.status = Status(rawValue: "Delivered")!
                self.addNewMessage(message: message)
                self.inboxRef.child(message.id).setValue(message.toAnyObject())
			}
		})
		

		
	}
	
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
    
    //consider extracting these elsewhere
    
    func addNewMessage(message: Message) {
        add(message: message)
        startMonitoring(message: message)
        saveAllMessages()
    }
    
    func loadAllMessages() {
		messages = []
        guard let savedItems = UserDefaults.standard.array(forKey: PreferencesKeys.savedItems) else { return }
		print("Saved Items \(savedItems.count)")
        for savedItem in savedItems {
            guard let message = NSKeyedUnarchiver.unarchiveObject(with: savedItem as! Data) as? Message else { continue }
			
            add(message: message)
        }
    }
    
    func saveAllMessages() {
        var items: [Data] = []
        for message in messages {
            let item = NSKeyedArchiver.archivedData(withRootObject: message)
            items.append(item)
        }
        UserDefaults.standard.set(items, forKey: PreferencesKeys.savedItems)
    }
    
    func add(message: Message) {
		messages.append(message)

        // should we display them on the map too???
        // map.addAnnotation(notification)
        // addRadiusOverlay(forNotification: notifications)
        // also, may be good to call a method updating status of the message to 'delivered'?
        // (tbd)
        updateMessagesCount()
    }
    
    func remove(message: Message) {
        if let indexInArray = messages.index(of: message) {
            messages.remove(at: indexInArray)
        }
        // map.removeAnnotion(message)
        // removeRadiusOverlay(forMessage: message)
        updateMessagesCount()
    }
    
    func updateMessagesCount() {
        //title = "Notifications (\(notifications.count))"
        //add a logic to ensure notifications.count < 20, iOS cannot handle more than that and may stop displaying them at all
        print("Messages (\(messages.count))")
    }
    
    func region(withMessage message: Message) -> CLCircularRegion {
        let region = CLCircularRegion(center: message.coordinate, radius: message.radius, identifier: message.id)
        region.notifyOnEntry = (message.eventType == .onEntry)
        region.notifyOnExit = !region.notifyOnEntry
        return region
    }
    
    func startMonitoring(message: Message) {
        if !CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
            //showAlert(withTitle:"Error", message: "This device does not fully support Türfy, some functionalities may not work correctly")
            return
        }
        if CLLocationManager.authorizationStatus() != .authorizedAlways {
            //showAlert(withTitle:"Warning", message: "Please grant Türfy permission to access the device location (Always on) in order for the app to work correctly")
        }
        let region = self.region(withMessage: message)
		
		if message.status.rawValue == "Delivered" {
			locationManager.startMonitoring(for: region)
			message.status = Status(rawValue: "Processed")!
			self.inboxRef.child(message.id).setValue(message.toAnyObject())
		}
		
    }
    
    func stopMonitoring(message: Message) {
        for region in locationManager.monitoredRegions {
            guard let circularRegion = region as? CLCircularRegion, circularRegion.identifier == message.id else { continue }
            locationManager.stopMonitoring(for: circularRegion)
        }
    }
	
	func saveData(message: Message) {
		
		let recipient: String = message.recipient
		let messageContent = message.toAnyObject()
		
		let itemRef = self.ref.child(recipient).childByAutoId()
		itemRef.setValue(messageContent)
	}


}
