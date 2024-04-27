const { expect } = require("chai");

describe("CarPooling and carPoolingCoordination", function () {
    let carPooling;
    let user1;
    let user2;

    // 新增的代码
    let carPoolingCoordination
    let user3;
    let user4;
    let user5;
    let user6;
    let user7;

    beforeEach(async function () {
        const CarPooling = await ethers.getContractFactory("CarPooling");
        // 部分修改
        [user1, user2, user3, user4, user5, user6, user7] = await ethers.getSigners();

        carPooling = await CarPooling.deploy();

        // 新增的代码
        const CarPoolingCoordination = await ethers.getContractFactory("CarPoolingCoordination");
        carPoolingCoordination = await CarPoolingCoordination.deploy();
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

    // 新增的代码
    // 我用汉字说个大概，英文怎么描述自己整理，注释是为了帮助你理解，不必要的多余的注释可以删除，保持上面的老师的风格即可
    it("测试startRide和completeRide函数", async function () {
        // user1注册为司机
        await carPooling.connect(user1).driverRegister();
        // user1创建拼车，10点出发、1个座位、单价10ETH、路线A->B
        await carPooling.connect(user1).createRide(10, 1, ethers.parseEther("10"), 0, 1);
        
        // user2注册为乘客
        await carPooling.connect(user2).passengerRegister();
        // user2支付10ETH预定上面的路线
        await expect(carPooling.connect(user2).joinRide(0, { value: ethers.parseEther("10") })).to.emit(carPooling, 'RideJoined').withArgs(0, user2.address);
        
        // 司机user1发车
        await carPooling.connect(user1).startRide(0);
        // 检查此车的状态
        await carPooling.getRideById(0).then((ride) => {
            // 已开始
            expect(ride.status).to.equal(2);
        });

        balanceBefore = await ethers.provider.getBalance(carPooling.getAddress());
        // 司机user1完成订单
        await carPooling.connect(user1).completeRide(0);
        balanceAfter = await ethers.provider.getBalance(carPooling.getAddress());
        // 检查司机是否获得收益
        expect(balanceAfter).to.equal(balanceBefore - ethers.parseEther("10"));

        // 检查此车的状态
        await carPooling.getRideById(0).then((ride) => {
            // 已完成
            expect(ride.status).to.equal(3);
        });
    });

    // 新增的代码
    it("测试awaitAssignRide函数", async function () {
        // user1注册为乘客
        await carPoolingCoordination.connect(user1).passengerRegister();
        // user1选择协调，路线A->B，期望10点出发，支付20ETH押金
        await carPoolingCoordination.connect(user1).awaitAssignRide(0, 1, 10, { value: ethers.parseEther("20") })
        
        // 检查是否加入协调
        await carPoolingCoordination.passengerWaitlist(0).then((waitRide) => {
            expect(waitRide.passenger).to.equal(user1.address);
            expect(waitRide.deposit).to.equal(ethers.parseEther("20"));
        });
    });

    // 新增的代码
    it("测试assignPassengersToRides函数1", async function () {
        // user1注册为司机
        await carPoolingCoordination.connect(user1).driverRegister();
        // user1创建拼车，4点出发、1个座位、单价10ETH、路线A->B
        await carPoolingCoordination.connect(user1).createRide(4, 1, ethers.parseEther("10"), 0, 1);

        // user2注册为司机
        await carPoolingCoordination.connect(user2).driverRegister();
        // user2创建拼车，15点出发、2个座位、单价10ETH、路线A->B
        await carPoolingCoordination.connect(user2).createRide(15, 2, ethers.parseEther("10"), 0, 1);

        // user4注册为乘客
        await carPoolingCoordination.connect(user4).passengerRegister();
        // user4选择协调，路线A->B，期望20点出发
        await carPoolingCoordination.connect(user4).awaitAssignRide(0, 1, 20, { value: ethers.parseEther("10") });

        // user5注册为乘客
        await carPoolingCoordination.connect(user5).passengerRegister();
        // user5选择协调，路线A->B，期望23点出发
        await carPoolingCoordination.connect(user5).awaitAssignRide(0, 1, 23, { value: ethers.parseEther("20") });

        // 系统调用assignPassengersToRides为乘客分配乘车
        await carPoolingCoordination.connect(user1).assignPassengersToRides();

        // 校验user4退款金额是否为0
        await carPoolingCoordination.connect(user4).passengerWaitlist(0).then((result) => {
            // 地址
            expect(result.passenger).to.equal(user4.address);
            // 押金
            expect(result.deposit).to.equal(ethers.parseEther("10"));
            // 退款金额
            expect(result.refund).to.equal(0);
            // 是否分配到user2车上
            expect(result.rideId).to.equal(1);
        })

        // 校验user5退款金额是否为10
        await carPoolingCoordination.connect(user5).passengerWaitlist(1).then((result) => {
            // 地址
            expect(result.passenger).to.equal(user5.address);
            // 押金
            expect(result.deposit).to.equal(ethers.parseEther("20"));
            // 退款金额
            expect(result.refund).to.equal(ethers.parseEther("10"));
            // 是否分配到user2车上
            expect(result.rideId).to.equal(1);
        })
    });

    // 新增的代码
    it("测试assignPassengersToRides函数2", async function () {
        // user1注册为司机
        await carPoolingCoordination.connect(user1).driverRegister();
        // user1创建拼车，23点出发、2个座位、单价10ETH、路线A->B
        await carPoolingCoordination.connect(user1).createRide(23, 2, ethers.parseEther("10"), 0, 1);

        // user2注册为司机
        await carPoolingCoordination.connect(user2).driverRegister();
        // user2创建拼车，10点出发、2个座位、单价10ETH、路线A->B
        await carPoolingCoordination.connect(user2).createRide(10, 2, ethers.parseEther("10"), 0, 1);

        // user4注册为乘客
        await carPoolingCoordination.connect(user4).passengerRegister();
        // user4选择协调，路线A->B，期望5点出发
        await carPoolingCoordination.connect(user4).awaitAssignRide(0, 1, 5, { value: ethers.parseEther("10") });

        // user5注册为乘客
        await carPoolingCoordination.connect(user5).passengerRegister();
        // user5选择协调，路线A->B，期望18点出发
        await carPoolingCoordination.connect(user5).awaitAssignRide(0, 1, 18, { value: ethers.parseEther("20") });

        // 系统调用assignPassengersToRides为乘客分配乘车
        await carPoolingCoordination.connect(user1).assignPassengersToRides();

        // 校验user4退款金额是否为0
        await carPoolingCoordination.connect(user4).passengerWaitlist(0).then((result) => {
            // 地址
            expect(result.passenger).to.equal(user4.address);
            // 押金
            expect(result.deposit).to.equal(ethers.parseEther("10"));
            // 退款金额
            expect(result.refund).to.equal(0);
            // 是否分配到user2车上
            expect(result.rideId).to.equal(1);
        })

        // 校验user5退款金额是否为10
        await carPoolingCoordination.connect(user5).passengerWaitlist(1).then((result) => {
            // 地址
            expect(result.passenger).to.equal(user5.address);
            // 押金
            expect(result.deposit).to.equal(ethers.parseEther("20"));
            // 退款金额
            expect(result.refund).to.equal(ethers.parseEther("10"));
            // 是否分配到user1车上
            expect(result.rideId).to.equal(0);
        })
    });

    // 新增的代码
    it("测试assignPassengersToRides函数3", async function () {
        // user1注册为司机
        await carPoolingCoordination.connect(user1).driverRegister();
        // user1创建拼车，8点出发、1个座位、单价10ETH、路线A->B
        await carPoolingCoordination.connect(user1).createRide(8, 1, ethers.parseEther("10"), 0, 1);

        // user2注册为司机
        await carPoolingCoordination.connect(user2).driverRegister();
        // user2创建拼车，14点出发、1个座位、单价10ETH、路线A->B
        await carPoolingCoordination.connect(user2).createRide(14, 1, ethers.parseEther("10"), 0, 1);

        // user4注册为乘客
        await carPoolingCoordination.connect(user4).passengerRegister();
        // user4选择协调，路线A->B，期望10点出发
        await carPoolingCoordination.connect(user4).awaitAssignRide(0, 1, 10, { value: ethers.parseEther("10") });

        // user5注册为乘客
        await carPoolingCoordination.connect(user5).passengerRegister();
        // user5选择协调，路线A->B，期望6点出发
        await carPoolingCoordination.connect(user5).awaitAssignRide(0, 1, 6, { value: ethers.parseEther("10") });

        // 系统调用assignPassengersToRides为乘客分配乘车
        await carPoolingCoordination.assignPassengersToRides();

        // 校验user4退款金额是否为0
        await carPoolingCoordination.connect(user4).passengerWaitlist(0).then((result) => {
            // 是否分配到user2车上
            expect(result.rideId).to.equal(1);
        })

        // 校验user5退款金额是否为10
        await carPoolingCoordination.connect(user5).passengerWaitlist(1).then((result) => {
            // 是否分配到user1车上
            expect(result.rideId).to.equal(0);
        })
    });

    // 新增的代码
    it("测试assignPassengersToRides函数4", async function () {
        // user1注册为司机
        await carPoolingCoordination.connect(user1).driverRegister();
        // user1创建拼车，4点出发、1个座位、单价10ETH、路线A->B
        await carPoolingCoordination.connect(user1).createRide(4, 1, ethers.parseEther("10"), 0, 1);

        // user2注册为司机
        await carPoolingCoordination.connect(user2).driverRegister();
        // user2创建拼车，9点出发、1个座位、单价10ETH、路线A->B
        await carPoolingCoordination.connect(user2).createRide(9, 1, ethers.parseEther("10"), 0, 1);

        // user3注册为司机
        await carPoolingCoordination.connect(user3).driverRegister();
        // user3创建拼车，10点出发、2个座位、单价10ETH、路线A->B
        await carPoolingCoordination.connect(user3).createRide(10, 1, ethers.parseEther("10"), 0, 1);

        // user4注册为乘客
        await carPoolingCoordination.connect(user4).passengerRegister();
        // user4选择协调，路线A->B，期望10点出发
        await carPoolingCoordination.connect(user4).awaitAssignRide(0, 1, 10, { value: ethers.parseEther("10") });

        // user5注册为乘客
        await carPoolingCoordination.connect(user5).passengerRegister();
        // user5选择协调，路线A->B，期望6点出发
        await carPoolingCoordination.connect(user5).awaitAssignRide(0, 1, 6, { value: ethers.parseEther("20") });

        // user6注册为乘客
        await carPoolingCoordination.connect(user6).passengerRegister();
        // user6选择协调，路线A->B，期望8点出发
        await carPoolingCoordination.connect(user6).awaitAssignRide(0, 1, 8, { value: ethers.parseEther("17") });

        // user7注册为乘客
        await carPoolingCoordination.connect(user7).passengerRegister();
        // user7选择协调，路线B->C，期望14点出发
        await carPoolingCoordination.connect(user7).awaitAssignRide(1, 2, 14, { value: ethers.parseEther("10") });

        // 系统调用assignPassengersToRides为乘客分配乘车
        await carPoolingCoordination.connect(user1).assignPassengersToRides();

        // 校验user4退款金额是否为0
        await carPoolingCoordination.connect(user4).passengerWaitlist(0).then((result) => {
            // 地址
            expect(result.passenger).to.equal(user4.address);
            // 押金
            expect(result.deposit).to.equal(ethers.parseEther("10"));
            // 退款金额
            expect(result.refund).to.equal(0);
        })

        // 校验user5退款金额是否为10
        await carPoolingCoordination.connect(user5).passengerWaitlist(1).then((result) => {
            // 地址
            expect(result.passenger).to.equal(user5.address);
            // 押金
            expect(result.deposit).to.equal(ethers.parseEther("20"));
            // 退款金额
            expect(result.refund).to.equal(ethers.parseEther("10"));
        })

        // 校验user6退款金额是否为7
        await carPoolingCoordination.connect(user6).passengerWaitlist(2).then((result) => {
            // 地址
            expect(result.passenger).to.equal(user6.address);
            // 押金
            expect(result.deposit).to.equal(ethers.parseEther("17"));
            // 退款金额
            expect(result.refund).to.equal(ethers.parseEther("7"));
        })

        // 校验user7是否因没有拼车信息匹配而全额退款了？
        await carPoolingCoordination.connect(user7).passengerWaitlist(3).then((result) => {
            // 地址
            expect(result.passenger).to.equal(user7.address);
            // 押金
            expect(result.deposit).to.equal(ethers.parseEther("10"));
            // 退款金额
            expect(result.refund).to.equal(ethers.parseEther("10"));
        })

        /**
         * 假设车辆有：车辆1、车辆2、车辆3，对应上面的rideId 0、1、2
         * 假设乘客有：乘客A、乘客B、乘客C、乘客D，对应上面的user4、user5、user6、user7，其中user7没有拼车信息匹配全额退款
         * 那么拼车方案有如下10种：
         * A1 B2 C3 = 6 + 3 + 8 = 17
         * A1 B3 C2 = 6 + 4 + 1 = 11
         * A2 B1 C3 = 1 + 2 + 2 = 5
         * A2 B3 C1 = 1 + 4 + 4 = 9
         * A3 B1 C2 = 0 + 2 + 1 = 3
         * A3 B2 C1 = 0 + 9 + 4 = 13
         * A1 B3 C3 = 6 + 4 + 2 = 12
         * A2 B3 C3 = 1 + 2 + 2 = 5
         * A3 B3 C1 = 0 + 4 + 4 = 8
         * A3 C3 B1 = 0 + 2 + 2 = 4
         * 因此手工穷举后，发现最优方案是第5种：A3 B1 C2，它的总时间偏差仅为3
         * 那么现在校验assignPassengersToRides的结果是不是符合预期
         */
        await carPoolingCoordination.connect(user4).passengerWaitlist(0).then((result) => {
            // 是否为A3
            expect(result.rideId).to.equal(2);
        })

        await carPoolingCoordination.connect(user5).passengerWaitlist(1).then((result) => {
            // 是否为B1
            expect(result.rideId).to.equal(0);
        })

        await carPoolingCoordination.connect(user6).passengerWaitlist(2).then((result) => {
            // 是否为C2
            expect(result.rideId).to.equal(1);
        })
    });
});