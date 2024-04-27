// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CarPooling {

    enum RideStatus {BookingOpen, FullyBooked, Started, Completed}
    enum Location {A, B, C}

    struct Ride {
        uint256 rideId;
        address driver;
        uint8 travelTime;
        uint8 availableSeats;
        uint8 totalSeats;
        uint256 seatPrice;
        Location origin;
        Location destination;
        RideStatus status; // status of the ride
        address [] passengerAddr; // addresses of all passengers who booked the ride
    }

    struct Driver {
        bool isRegistered;
        bool hasRide;
    }

    struct Passenger {
        bool isRegistered;
        bool hasRide;
    }

    mapping(uint256 => Ride) internal rides;
    mapping(address => Driver) internal drivers;
    mapping(address => Passenger) internal passengers; 

    // Your auxiliary data structures here, if required
    

    event RideCreated(uint256 rideId, address driver, uint8 travelTime, uint8 availableSeats, uint256 seatPrice, Location origin, Location destination);
    event RideJoined(uint256 rideId, address passenger);
    event RideStarted(uint256 rideId);
    event RideCompleted(uint256 rideId);

    modifier onlyDriver(){
        // Your implementation here
    }
    modifier onlyPassenger(){
        // Your implementation here
    }
    modifier notDriver(){
        // Your implementation here
    }
    modifier notPassenger(){
        // Your implementation here
    }
    modifier driverSingleRide(){
        // Your implementation here
    }
    modifier passengerSingleRide(){
        // Your implementation here
    }

    function passengerRegister() public notPassenger{
        // Your implementation here
    }

     function driverRegister() public notDriver{
        // Your implementation here
    }

    function createRide(uint8 _travelTime, uint8 _availableSeats, uint256 _seatPrice, Location _origin, Location _destination) public onlyDriver driverSingleRide{
        // Your implementation here
    }

    function findRides(Location _source, Location _destination) public view returns (uint256[] memory) {
        // Your implementation here
    }

    function joinRide(uint256 _rideId) public payable onlyPassenger passengerSingleRide{
        // Your implementation here
    }

    function startRide(uint256 _rideId) public onlyDriver{
        // Your implementation here
    }

    function completeRide(uint256 _rideId) public onlyDriver{
        // Your implementation here
    }

    // -------------------- Already implemented functions, do not modify ------------------

    function getDriver(address addr) public view returns (Driver memory){
        return(drivers[addr]);
    }

    function getPassenger(address addr) public view returns (Passenger memory){
        return(passengers[addr]);
    }

    function getRideById(uint256 _rideId) public view returns (Ride memory){
        return(rides[_rideId]);
    }
}



// ----------------------------------- Coordination -----------------------------------

contract CarPoolingCoordination is CarPooling {

    // Your data structures here

    function awaitAssignRide(Location _source, Location _destination, uint8 preferredTravelTime) public payable onlyPassenger {
        // Your implementation here
    }

    function assignPassengersToRides() public {
        // Your implementation here
    }
}