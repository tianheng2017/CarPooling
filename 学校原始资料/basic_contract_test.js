const { expect } = require("chai");

describe("CarPooling", function () {
    let carPooling;
    let user1;
    let user2;

    beforeEach(async function () {
        const CarPooling = await ethers.getContractFactory("CarPooling");
        [user1, user2, user3, user4] = await ethers.getSigners();

        carPooling = await CarPooling.deploy();
    });

    it("should allow users to register as a passenger", async function () {
        // Check: Unregistered user should not be a passenger in the member struct
        await carPooling.getPassenger(user1.address).then((passenger) => {
            expect(passenger.isRegistered).to.be.false;
            expect(passenger.hasRide).to.be.false;
        })
        // Register user as a passenger
        await carPooling.connect(user1).passengerRegister();
        // Check: Registered user should be a passenger
        await carPooling.getPassenger(user1.address).then((passenger) => {
            expect(passenger.isRegistered).to.be.true;
            expect(passenger.hasRide).to.be.false;
        })
        // Check: Registered passenger should not be able to register as a passenger again
        await expect(carPooling.connect(user1).passengerRegister()).to.be.reverted;
    });

    it("should allow users to register as a driver", async function () {
        // Check: Unregistered user should not be a driver in the member struct
        await carPooling.getDriver(user1.address).then((driver) => {
            expect(driver.isRegistered).to.be.false;
            expect(driver.hasRide).to.be.false;
        })
        // Register user as a driver
        await carPooling.connect(user1).driverRegister();
        // Check: Registered user should be a driver in the member struct
        await carPooling.getDriver(user1.address).then((driver) => {
            expect(driver.isRegistered).to.be.true;
            expect(driver.hasRide).to.be.false;
        })
        // Check: Registered driver should not be able to register as a driver again
        await expect(carPooling.connect(user1).driverRegister()).to.be.reverted;
    });

    it("should allow drivers to create rides", async function () {
        // Check: Unregistered user should not be able to create a ride
        await expect(carPooling.connect(user1).createRide(10, 5, 10, 0, 1)).to.be.reverted;
        // Register user as a driver
        await carPooling.connect(user1).driverRegister();
        // Check: Registered driver should be able to create a ride with valid parameters and emit RideCreated event
        await expect(carPooling.connect(user1).createRide(10, 5, 10, 0, 1)).to.emit(carPooling, 'RideCreated').withArgs(0, user1.address, 10, 5, 10, 0, 1);
        await carPooling.getRideById(0).then((ride) => {
            expect(ride.driver).to.equal(user1.address);
            expect(ride.travelTime).to.equal(10);
            expect(ride.availableSeats).to.equal(5);
            expect(ride.seatPrice).to.equal(10);
            expect(ride.origin).to.equal(0);
            expect(ride.destination).to.equal(1);
            expect(ride.status).to.equal(0);
            expect(ride.passengerAddr.length).to.equal(0);
        })
    });

    it("should allow users to query rides", async function () {
        // Requires correct implementation of createRide
        // Create three rides
        await carPooling.connect(user1).driverRegister();
        await carPooling.connect(user1).createRide(10, 5, ethers.parseEther("10"), 0, 1);
        await carPooling.connect(user2).driverRegister();
        await carPooling.connect(user2).createRide(11, 3, ethers.parseEther("10"), 0, 1);
        await carPooling.connect(user3).driverRegister();
        await carPooling.connect(user3).createRide(12, 2, ethers.parseEther("10"), 1, 2);
        // Check: User should be able to query rides with valid parameters
        await carPooling.findRides(0, 1).then((rideIds) => {
            expect(rideIds.length).to.equal(2);
            expect(rideIds[0]).to.equal(0);
            expect(rideIds[1]).to.equal(1);
        })
        await carPooling.findRides(0, 2).then((rideIds) => {
            expect(rideIds.length).to.equal(0);
        })
        await carPooling.findRides(1, 2).then((rideIds) => {
            expect(rideIds.length).to.equal(1);
            expect(rideIds[0]).to.equal(2);
        })
    });

    it("should allow passengers to join rides", async function () {
        // Requires correct implementation of createRide
        // Create a ride
        await carPooling.connect(user1).driverRegister();
        await carPooling.connect(user1).createRide(10, 2, ethers.parseEther("10"), 0, 1);
        // Register user as a passenger
        await carPooling.connect(user2).passengerRegister();
        // Check: Registered passenger should not be able to join a ride with invalid parameters
        await expect(carPooling.connect(user2).joinRide(1)).to.be.reverted;
        await expect(carPooling.connect(user2).joinRide(0, {value: ethers.parseEther("9")})).to.be.reverted;
        // Check: Registered passenger should be able to join a ride with valid parameters and emit RideJoined event
        balanceBefore = await ethers.provider.getBalance(carPooling.getAddress());
        await expect(carPooling.connect(user2).joinRide(0, {value: ethers.parseEther("10")})).to.emit(carPooling, 'RideJoined').withArgs(0, user2.address);
        balanceAfter = await ethers.provider.getBalance(carPooling.getAddress());
        // Check: Joined ride should transfer funds to contract
        expect(balanceAfter).to.equal(balanceBefore + ethers.parseEther("10"));
        await carPooling.getRideById(0).then((ride) => {
            expect(ride.passengerAddr.length).to.equal(1);
            expect(ride.passengerAddr[0]).to.equal(user2.address);
        });
        // Check: Full ride should change status to booking closed
        await carPooling.connect(user3).passengerRegister();
        expect(await carPooling.connect(user3).joinRide(0, {value: ethers.parseEther("10")})).to.emit(carPooling, 'RideJoined').withArgs(0, user3.address);
        await carPooling.getRideById(0).then((ride) => {
            expect(ride.status).to.equal(1);
        });
    });

});