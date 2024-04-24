// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CarPooling {

    // 拼车状态枚举
    enum RideStatus {BookingOpen, FullyBooked, Started, Completed}
    // 拼车地点枚举
    enum Location {A, B, C}

    // 拼车订单结构体
    struct Ride {
        // 拼车ID
        uint256 rideId;
        // 司机地址
        address driver;
        // 出行开始时间，0-23
        uint8 travelTime;
        // 剩余座位数
        uint8 availableSeats;
        // 总座位数
        uint8 totalSeats;
        // 座位单价
        uint256 seatPrice;
        // 起点
        Location origin;
        // 终点
        Location destination;
        // 状态：开放预订、已满、已开始、已完成
        RideStatus status; // status of the ride
        // 预订该拼车的乘客数组
        address [] passengerAddr; // addresses of all passengers who booked the ride
    }

    // 司机结构体
    struct Driver {
        bool isRegistered;
        bool hasRide;
    }

    // 乘客结构体
    struct Passenger {
        bool isRegistered;
        bool hasRide;
    }

    // 拼车数据映射
    mapping(uint256 => Ride) internal rides;
    // 司机数据映射
    mapping(address => Driver) internal drivers;
    // 乘客数据映射
    mapping(address => Passenger) internal passengers;

    // 全局唯一ID
    uint nextId;
    // 处于“BookingOpen”状态的ID组
    uint[] bookingOpenIds;

    // 拼车订单创建事件
    event RideCreated(uint256 rideId, address driver, uint8 travelTime, uint8 availableSeats, uint256 seatPrice, Location origin, Location destination);
    // 预订成功事件
    event RideJoined(uint256 rideId, address passenger);
    // 司机发车事件
    event RideStarted(uint256 rideId);
    // 拼车完成事件
    event RideCompleted(uint256 rideId);

    modifier onlyDriver(){
        // 确保调用者是司机不是乘客
        require(drivers[msg.sender].isRegistered && !passengers[msg.sender].isRegistered, "The caller must be a registered driver");
        _;
    }
    modifier onlyPassenger(){
        // 确保调用者是乘客不是司机
        require(passengers[msg.sender].isRegistered && !drivers[msg.sender].isRegistered, "The caller must be a passenger driver");
        _;
    }
    modifier notDriver(){
        // 确保调用者没有注册为司机
      require(!drivers[msg.sender].isRegistered, "The caller must not be a registered driver");
      _;
    }
    modifier notPassenger(){
        // 确保调用者没有注册为乘客
        require(!passengers[msg.sender].isRegistered, "The caller must not be a registered passenger");
        _;
    }
    modifier driverSingleRide(){
        // 确保司机没有在订单未完成前多次创建拼车订单
        require(!drivers[msg.sender].hasRide, "A driver can only create one ride");
        _;
    }
    modifier passengerSingleRide(){
        // 确保乘客没有在订单未完成前多次加入拼车
        require(!passengers[msg.sender].hasRide, "A passenger can only join one ride");
        _;
    }

    // 注册为乘客
    function passengerRegister() public notPassenger{
        passengers[msg.sender] = Passenger(true, false);
    }

    // 注册为司机
    function driverRegister() public notDriver{
        drivers[msg.sender] = Driver(true, false);
    }

    // 司机创建拼车订单
    function createRide(uint8 _travelTime, uint8 _availableSeats, uint256 _seatPrice, Location _origin, Location _destination) public onlyDriver driverSingleRide{
        // 行程时间必须在0-23之间
        require(_travelTime >= 0 && _travelTime <= 23, "Travel time must be between 0 and 23");
        // 可用座位必须大于0
        require(_availableSeats > 0, "Available seats must be greater than 0");
        // 座位单价必须大于0
        require(_seatPrice > 0, "The seat price must be greater than 0");
        // 起点和终点必须不同
        require(_origin != _destination, "The starting and ending points should be different");

        // 构建拼车订单
        rides[nextId] = Ride({
            // 拼车ID
            rideId: nextId,
            // 司机区块链地址
            driver: msg.sender,
            // 出行开始时间
            travelTime: _travelTime,
            // 剩余座位数
            availableSeats: _availableSeats,
            // 总座位数
            totalSeats: _availableSeats,
            // 座位单价
            seatPrice: _seatPrice,
            // 起点
            origin: Location(_origin),
            // 终点
            destination: Location(_destination),
            // 状态：开放预订、已满、已开始、已完成
            status: RideStatus.BookingOpen,
            // 预订该拼车的乘客数组
            passengerAddr: new address[](0)
        });
        
        // 标记该司机发起了拼车订单
        drivers[msg.sender].hasRide = true;
        // push到处于“BookingOpen”状态的ID组
        bookingOpenIds.push(nextId);
        // 触发拼车订单创建事件
        emit RideCreated(nextId, msg.sender, _travelTime, _availableSeats, _seatPrice, Location(_origin), Location(_destination));
        // 全局唯一id自增
        nextId++;
    }

    // 查询指定起点和终点的所有拼车订单ID
    function findRides(Location _source, Location _destination) public view returns (uint256[] memory) {
        require(_source != _destination, "The starting and ending points should be different");
        
        // 计算符合条件的订单数量
        uint256 count = 0;
        for (uint256 i = 0; i < bookingOpenIds.length; i++) {
            Ride storage ride = rides[bookingOpenIds[i]];
            if (ride.origin == _source && ride.destination == _destination && ride.status == RideStatus.BookingOpen) {
                count++;
            }
        }
        
        // 创建定长内存数组存储所有符合条件的订单ID
        uint[] memory rideIds = new uint256[](count);
        
        // 再次遍历，将符合条件的ID复制到内存数组中
        uint256 index = 0;
        for (uint256 i = 0; i < bookingOpenIds.length; i++) {
            Ride storage ride = rides[bookingOpenIds[i]];
            if (ride.origin == _source && ride.destination == _destination) {
                rideIds[index] = ride.rideId;
                index++;
            }
        }

        return rideIds;
    }

    // 乘客拼车
    function joinRide(uint256 _rideId) public payable onlyPassenger passengerSingleRide{
        // 校验订单ID，不能超过当前最大订单ID
        require(_rideId <= nextId, "rideId does not exist");
        // 校验金额
        require(msg.value == rides[_rideId].seatPrice, "Carpool price must be correct");

        // 拿到订单信息
        Ride storage ride = rides[_rideId];

        // 校验订单状态
        require(ride.status == RideStatus.BookingOpen, "Carpool status must be BookingOpen");

        // 变更乘客已经拼车
        passengers[msg.sender].hasRide = true;
        // 如果剩余座位数只有一个了
        if (ride.availableSeats == 1) {
            // 变更订单状态：已满
            ride.status = RideStatus.FullyBooked;
            // 从bookingOpenIds中移除此ID
            for (uint256 i = 0; i < bookingOpenIds.length; i++) {
                // 如果找到
                if (bookingOpenIds[i] == _rideId) {
                    // 将数组最后一位覆盖过来
                    bookingOpenIds[i] = bookingOpenIds[bookingOpenIds.length - 1];
                    // 再弹出最后一位，达到remove元素的目的
                    bookingOpenIds.pop();
                }
            }

        }
        // 剩余座位数 - 1
        ride.availableSeats -= 1;
        // 记录乘客地址
        ride.passengerAddr.push(msg.sender);
        
        // 触发乘客拼车事件
        emit RideJoined(_rideId, msg.sender);
    }

    // 司机发车
    function startRide(uint256 _rideId) public onlyDriver{
        // 获取拼车订单
        Ride storage ride = rides[_rideId];
        // 校验订单状态
        require(ride.status == RideStatus.FullyBooked, "The order status must be FullyBooked");
        // 校验司机
        require(ride.driver == msg.sender, "The driver can only start his own ride");

        // 变更订单状态为已发车
        ride.status = RideStatus.Started;
        // 触发发车事件
        emit RideStarted(_rideId);
    }

    // 司机完成订单
    function completeRide(uint256 _rideId) public onlyDriver{
        // 获取拼车订单
        Ride storage ride = rides[_rideId];
        // 校验订单状态
        require(ride.status == RideStatus.Started, "The order status must be Started");
        // 校验司机
        require(ride.driver == msg.sender, "The driver can only start his own ride");

        // 变更订单状态为已完成
        ride.status = RideStatus.Completed;
        // 变更司机状态
        drivers[msg.sender].hasRide = false;

        // 将乘客的付款转移到司机账户
        payable(ride.driver).transfer(ride.seatPrice * ride.totalSeats);
        // 触发订单完成事件
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

    // 等待分配结构体
    struct PassengerWaitlist {
        // 乘客地址
        address passenger;
        // 起点
        Location source;
        // 终点
        Location destination;
        // 期望时间
        uint8 preferredTravelTime;
        // 足够大的押金
        uint256 deposit;
        // 是否加入等待列表
        bool isJoin;
        // 是否分配成功
        bool isAssigned;
    }

    // 等待分配唯一ID
    uint nextAwaitId;

    // 等待信息列表
    mapping(uint => PassengerWaitlist) public passengerWaitlist;

    // 等待ID组
    uint[] awaitIds;

    // 加入等待事件
    event AwaitAssignRideJoined(address passenger);

    function awaitAssignRide(Location _source, Location _destination, uint8 _preferredTravelTime) public payable onlyPassenger {
        // pdf说：假设协调的乘客总是支付足够的押金，足以加入任何乘车（因此在分配乘车时不需要考虑这个因素），简单校验下即可
        require(msg.value > 0, "Insufficient deposit");
        // pdf说：一个乘客不能两次调用awaitAssignRide
        require(passengerWaitlist[msg.sender].isJoin == false, "A passenger cannot call awaitAssignRide twice");

        // 加入等待信息列表
        passengerWaitlist[nextAwaitId] = PassengerWaitlist({
            passenger: msg.sender,
            source: _source,
            destination: _destination,
            preferredTravelTime: _preferredTravelTime,
            deposit: msg.value,
            isJoin: true,
            isAssigned: false
        });

        // 加入等待ID组
        awaitIds.push(nextAwaitId);

        // 触发加入等待列表事件
        emit AwaitAssignRideJoined(msg.sender);

        // 唯一ID自增
        nextAwaitId++;
    }

    function assignPassengersToRides() public {
        // Your implementation here
    }
}