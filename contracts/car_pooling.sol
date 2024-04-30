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
    uint public nextId;
    uint[] public bookingOpenIds;

    event RideCreated(uint256 rideId, address driver, uint8 travelTime, uint8 availableSeats, uint256 seatPrice, Location origin, Location destination);
    event RideJoined(uint256 rideId, address passenger);
    event RideStarted(uint256 rideId);
    event RideCompleted(uint256 rideId);

    modifier onlyDriver(){
        require(drivers[msg.sender].isRegistered && !passengers[msg.sender].isRegistered, "The caller must be a registered driver");
        _;
    }
    modifier onlyPassenger(){
        require(passengers[msg.sender].isRegistered && !drivers[msg.sender].isRegistered, "The caller must be a passenger driver");
        _;
    }
    modifier notDriver(){
      require(!drivers[msg.sender].isRegistered, "The caller must not be a registered driver");
      _;
    }
    modifier notPassenger(){
        require(!passengers[msg.sender].isRegistered, "The caller must not be a registered passenger");
        _;
    }
    modifier driverSingleRide(){
        require(!drivers[msg.sender].hasRide, "A driver can only create one ride");
        _;
    }
    modifier passengerSingleRide(){
        require(!passengers[msg.sender].hasRide, "A passenger can only join one ride");
        _;
    }

    function passengerRegister() public notPassenger{
        passengers[msg.sender] = Passenger(true, false);
    }

    function driverRegister() public notDriver{
        drivers[msg.sender] = Driver(true, false);
    }

    function createRide(uint8 _travelTime, uint8 _availableSeats, uint256 _seatPrice, Location _origin, Location _destination) public onlyDriver driverSingleRide{
        require(_travelTime >= 0 && _travelTime <= 23, "Travel time must be between 0 and 23");
        require(_availableSeats > 0, "Available seats must be greater than 0");
        require(_seatPrice > 0, "The seat price must be greater than 0");
        require(_origin != _destination, "The starting and ending points should be different");

        rides[nextId] = Ride({
            rideId: nextId,
            driver: msg.sender,
            travelTime: _travelTime,
            availableSeats: _availableSeats,
            totalSeats: _availableSeats,
            seatPrice: _seatPrice,
            origin: Location(_origin),
            destination: Location(_destination),
            status: RideStatus.BookingOpen,
            passengerAddr: new address[](0)
        });
        
        bookingOpenIds.push(nextId);
        drivers[msg.sender].hasRide = true;
        emit RideCreated(nextId, msg.sender, _travelTime, _availableSeats, _seatPrice, Location(_origin), Location(_destination));
        nextId++;
    }

    function findRides(Location _source, Location _destination) public view returns (uint256[] memory) {
        require(_source != _destination, "The starting and ending points should be different");
        uint256 count = 0;
        for (uint256 i = 0; i < bookingOpenIds.length; i++) {
            Ride storage ride = rides[bookingOpenIds[i]];
            if (ride.origin == _source && ride.destination == _destination && ride.status == RideStatus.BookingOpen) {
                count++;
            }
        }
        uint[] memory rideIds = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < bookingOpenIds.length; i++) {
            Ride storage ride = rides[bookingOpenIds[i]];
            if (ride.origin == _source && ride.destination == _destination && ride.status == RideStatus.BookingOpen) {
                rideIds[index] = ride.rideId;
                index++;
            }
        }

        return rideIds;
    }

    function _joinRide(uint256 _rideId, address _user) internal {
        Ride storage ride = rides[_rideId];

        passengers[_user].hasRide = true;
        ride.passengerAddr.push(_user);

        if (ride.availableSeats == 1) {
            ride.status = RideStatus.FullyBooked;
            for (uint256 i = 0; i < bookingOpenIds.length; i++) {
                if (bookingOpenIds[i] == _rideId) {
                    bookingOpenIds[i] = bookingOpenIds[bookingOpenIds.length - 1];
                    bookingOpenIds.pop();
					break;
                }
            }
        }

        ride.availableSeats -= 1;
    }

    function joinRide(uint256 _rideId) public payable onlyPassenger passengerSingleRide{
        require(_rideId < nextId, "rideId does not exist");
        require(msg.value == rides[_rideId].seatPrice, "Carpool price must be correct");
        require(passengers[msg.sender].hasRide == false, "A passenger cannot join multiple rides simultaneously");
        Ride storage ride = rides[_rideId];
        require(ride.status == RideStatus.BookingOpen, "Carpool status must be BookingOpen");
        require(ride.availableSeats > 0, "There must be remaining seats in the ride");

        _joinRide(_rideId, msg.sender);
        emit RideJoined(_rideId, msg.sender);
    }

    function startRide(uint256 _rideId) public onlyDriver{
        Ride storage ride = rides[_rideId];
        require(ride.status == RideStatus.FullyBooked, "The order status must be FullyBooked");
        require(ride.driver == msg.sender, "The driver can only start his own ride");

        ride.status = RideStatus.Started;
        emit RideStarted(_rideId);
    }

    function completeRide(uint256 _rideId) public onlyDriver{
        Ride storage ride = rides[_rideId];
        require(ride.status == RideStatus.Started, "The order status must be Started");
        require(ride.driver == msg.sender, "The driver can only start his own ride");

        ride.status = RideStatus.Completed;
        drivers[msg.sender].hasRide = false;
        for (uint i = 0;i < ride.passengerAddr.length;i++) {
            passengers[ride.passengerAddr[i]].hasRide = false;
        }
        payable(ride.driver).transfer(ride.seatPrice * ride.totalSeats);
        emit RideCompleted(_rideId);
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
    struct PassengerWait {
        uint256 awaitId;
        address passenger;
        Location source;
        Location destination;
        uint8 preferredTravelTime;
        uint256 deposit;
        uint256 rideId;
        uint256 refund;
    }

    struct Deviation {
        uint256 index;
        uint8 data;
        uint256 rideId;
    }

    uint public nextAwaitId;
    mapping(uint => PassengerWait) public passengerWaitlist;
    uint[] public awaitIds;
	
    function abs(uint8 a, uint8 b) internal pure returns(uint8) {
        if (a >= b) {
            return a - b;
        } else {
            return b - a;
        }
    }

    function awaitAssignRide(Location _source, Location _destination, uint8 _preferredTravelTime) public payable onlyPassenger {
        require(msg.value > 0, "Insufficient deposit");
        require(passengers[msg.sender].hasRide == false, "Passenger has already joined a ride and cannot join another");

        passengerWaitlist[nextAwaitId] = PassengerWait({
            awaitId: nextAwaitId,
            passenger: msg.sender,
            source: _source,
            destination: _destination,
            preferredTravelTime: _preferredTravelTime,
            deposit: msg.value,
            rideId: 0,
            refund: 0
        });

        awaitIds.push(nextAwaitId);
        passengers[msg.sender].hasRide = true;
        nextAwaitId++;
    }

    function assignPassengersToRides() public {
        require(awaitIds.length > 0, "No passengers waiting for a ride");
        require(bookingOpenIds.length > 0, "No rides available");

        for (uint i = 0; i < awaitIds.length - 1; i++) {
            for (uint j = 0; j < awaitIds.length - i - 1; j++) {
                uint time_a = passengerWaitlist[awaitIds[j]].preferredTravelTime;
                uint time_b = passengerWaitlist[awaitIds[j + 1]].preferredTravelTime;
                if (time_a > time_b) {
                    uint256 temp = awaitIds[j];
                    awaitIds[j] = awaitIds[j + 1];
                    awaitIds[j + 1] = temp;
                }
            }
        }

        for (uint256 i = 0; i < awaitIds.length; i++) {
            PassengerWait storage passengerWait = passengerWaitlist[awaitIds[i]];
            uint256[] memory tempRides = findRides(passengerWait.source, passengerWait.destination);

            if (tempRides.length == 0) {
                payable(passengerWait.passenger).transfer(passengerWait.deposit);
                passengerWait.refund = passengerWait.deposit;
                continue;
            }

            Deviation[] memory deviation = new Deviation[](tempRides.length);

            for (uint256 j = 0; j < tempRides.length; j++) {
                deviation[j] = Deviation({
                    index: j,
                    data: abs(rides[tempRides[j]].travelTime, passengerWait.preferredTravelTime),
                    rideId: tempRides[j]
                });
            }

            uint256 minIndex = deviation[0].index;
            uint256 min = deviation[0].data;
            uint256 minRideId = deviation[0].rideId;
            for (uint k = 0; k < deviation.length; k++) {
                if (deviation[k].data < min) {
                    min = deviation[k].data;
                    minIndex = deviation[k].index;
                    minRideId = deviation[k].rideId;
                }
            }

            _joinRide(minRideId, passengerWait.passenger);

            if (passengerWait.deposit > rides[minRideId].seatPrice) {
                uint refund = passengerWait.deposit - rides[minRideId].seatPrice;
                payable(passengerWait.passenger).transfer(refund);
                passengerWait.refund = refund;
            }

            passengerWait.rideId = minRideId;
        }
    }
}