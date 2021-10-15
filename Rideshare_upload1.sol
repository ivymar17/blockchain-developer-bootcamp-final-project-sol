pragma solidity ^0.8.0;

contract RideShare {

    address[] public drivers;
    address public ridesAvailable;
    
    struct Ride {
      address driver; 
      address rider; 
      uint256 fare;
      bool paid;
      bool booked;
      bool accept;
    }
    mapping (uint256 => mapping (string => mapping (string => Ride))) public rides;

    struct costMiles { //populate struct at deployment
      uint256 miles;
      uint256 cost;
    }

    mapping (string => costMiles) private zonesPrices; //prices and miles within neighborhoods table.
    mapping (string => uint) private trafficVals; //established traffic values according traffic conditions
                                                   //for example: high traffic = 4, medium = 2, low = 0. in $$. expenses of time and gas
    mapping (address => bool) public isUser; 
      
    event RideCreated(address driver, string from, string to, uint256 depTime, uint256 fare);
    event RideRequested(address rider, address driverAvailable);
    event DriverRequested(address driver, uint rideTime); 
    event NoRide(address driver, uint rideTime);  
    event RideAccepted(address driver, uint rideTime); 
    event Paid(address driver, address rider, uint fare);
    event Unpaid(address driver, uint fare);
    event zoneAdded(string location, uint miles, uint cost);

   /*constructor () public { //define this constructor
        address owner = msg.sender;
        deploy tables with prices and distances?
        Only owner modifier?
        costMiles //struct populate? 
        rideBasePrices;
        rideBaseZones;
        zonesPrices;     
    }*/
    receive() external payable {  
        revert();
    }
    //
    //receives the data from a App interface in js. Driver initiates creation.
    //
    function createRide(string memory fromLoc, string memory destLoc, uint256 distance, uint256 depTime, string memory traffStat) external returns(bool) {
       //uint256 distance = pass the destination. Geolocation gets location, calculated distance. Driver from front-end js 
        //receives neighborhood location in string. Location will be standarized by neighborhood. Populated as written from a table.
        uint fare = getPrice(fromLoc, destLoc, distance, traffStat); //distance calculated above from geolocation data.
        rides[depTime][fromLoc][destLoc] = Ride({
            driver: msg.sender,
            rider: address(0x0),
            fare: fare,
            paid: false,
            booked: false,
            accept: false
        });
        emit RideCreated(msg.sender, fromLoc, destLoc, depTime, fare);
        return true;
    }

    //Get the price for the ride.
    function getPrice(string memory fromLoc, string memory destLoc, uint256 distance, string memory traffStat) private view returns(uint256) {
        uint priceLoc;
        require(zonesPrices[fromLoc].cost > 0, "location from does not exist");
        require(zonesPrices[destLoc].cost > 0, "location to does not exist");
        if (compareString(fromLoc, destLoc)) {
            priceLoc = zonesPrices[destLoc].cost; //price set within a single geolocation zone
        } else {
            priceLoc = (((zonesPrices[fromLoc].cost + zonesPrices[destLoc].cost) * distance) / (zonesPrices[fromLoc].miles + zonesPrices[destLoc].miles)); //take into account distance across different locations
        } 
        return (trafficVals[traffStat] + priceLoc); //increase price depending traffic 
    }
    //How to initiate this function from an active notification request passing the ride info....
    function acceptRide(uint rideTime, string memory destLoc, string memory toLoc) public returns(bool) {     
        Ride storage r = rides[rideTime][destLoc][toLoc];
        require(msg.sender == r.driver, "You didn't offer this ride!");
        require(r.booked == true, "Ride is not requested");
        emit RideAccepted(msg.sender, rideTime); 
        return r.accept = true;
    }
    
    function compareString(string memory a, string memory b) internal pure returns(bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
    
    function addZonesPrice(uint256 miles, uint256 cost, string memory location) external returns(bool) {
        zonesPrices[location] = costMiles({
            miles: miles,
            cost: cost
        });
        emit zoneAdded(location, miles, cost);
        return true;
    }
    
    //
    //User request a drive from app js Module.
    //
    
    function reqRides(uint rideTime, string memory destLoc, string memory toLoc) public returns (bool) {
       //pass the destination. Geolocation gets location, Driver from front-end js 
        isUser[msg.sender] = true; //value updated in front-end!! Not here. just for testing now        
        require(isUser[msg.sender] == true, "Must register user"); //set when user register in js
        Ride storage r = rides[rideTime][destLoc][toLoc];
        require(msg.sender != r.driver, "Imposible scenario: You are the Driver and User!");
        require(r.fare > 0, "No rides available");
        require(r.booked == false, "Ride is booked");
        reqDriver(rideTime, destLoc, toLoc);
        emit RideRequested(msg.sender, r.driver);
        return r.booked;         
    }
    //selected from the available rides returned matching ride to fromlocation destination and time. 
    //Loop through available rides to select dpending diffremt selected parameters: price, distance, etc.
    function reqDriver(uint rideTime, string memory destLoc, string memory toLoc) internal returns (bool) {        
        Ride storage r = rides[rideTime][destLoc][toLoc];
        if (r.fare > 0) {       
            r.booked = true;
            r.rider = msg.sender;
            emit DriverRequested(msg.sender, rideTime); 
        } else {
            emit NoRide(msg.sender, rideTime); 
        }    
        return r.booked;
    }

//develop this function
    function payRide(uint rideTime, string memory destLoc, string memory toLoc) public payable returns(bool) {
        Ride storage r = rides[rideTime][destLoc][toLoc];
        require(r.booked == true, "You did not book this ride");
        require(r.paid == false, "Wrong ride. It is already paid");
        require(r.accept == true, "Not accepted request");
        require(r.rider == msg.sender, "You did not request this ride");
        
        //r.paid = true;
        //(bool success, bytes memory data) = r.driver.call{value: r.fare}("");
        require(msg.value >= r.fare, "Not enough money to pay ride");
        r.paid = true;
        payable(r.driver).transfer(msg.value);
        
       // if (success) {
           
        emit Paid(r.driver, r.rider, r.fare);
        
        //} else {
        //    emit Unpaid(r.driver, r.fare);
        //    r.paid = false;
       // }
        return r.paid;
    }
}    

    