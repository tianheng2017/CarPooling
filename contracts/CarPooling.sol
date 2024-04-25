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
        RideStatus status;
        // 该拼车订单的所有乘客
        address [] passengerAddr;
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
    // 动态的保持较好的燃气消耗水平，避免for循环大范围的查找BookingOpen状态订单
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
        // 确保调用者只能是司机
        require(drivers[msg.sender].isRegistered && !passengers[msg.sender].isRegistered, "The caller must be a registered driver");
        _;
    }
    modifier onlyPassenger(){
        // 确保调用者只能是乘客
        require(passengers[msg.sender].isRegistered && !drivers[msg.sender].isRegistered, "The caller must be a passenger driver");
        _;
    }
    modifier notDriver(){
        // 确保调用者不是司机
      require(!drivers[msg.sender].isRegistered, "The caller must not be a registered driver");
      _;
    }
    modifier notPassenger(){
        // 确保调用者不是乘客
        require(!passengers[msg.sender].isRegistered, "The caller must not be a registered passenger");
        _;
    }
    modifier driverSingleRide(){
        // 确保司机没有在订单未完成前多次创建拼车订单
        require(!drivers[msg.sender].hasRide, "A driver can only create one ride");
        _;
    }
    modifier passengerSingleRide(){
        // 确保乘客没有在订单未完成前多次预定拼车
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
        // 座位数量必须大于0
        require(_availableSeats > 0, "Available seats must be greater than 0");
        // 单价必须大于0
        require(_seatPrice > 0, "The seat price must be greater than 0");
        // 起点和终点不能相同
        require(_origin != _destination, "The starting and ending points should be different");
        // 司机不能同时创建多个拼车订单
        require(drivers[msg.sender].hasRide == false, "A driver cannot create multiple rides simultaneously");

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
        
        // 标记该司机创建了拼车订单
        drivers[msg.sender].hasRide = true;

        // push到bookingOpenIds中
        bookingOpenIds.push(nextId);

        // 触发拼车订单创建事件
        emit RideCreated(nextId, msg.sender, _travelTime, _availableSeats, _seatPrice, Location(_origin), Location(_destination));
        // 全局唯一id自增
        nextId++;
    }

    // 查询指定起点和终点的所有拼车订单ID
    // 这里的输出是按照travelTime从小到大排了序的
    function findRides(Location _source, Location _destination) public view returns (uint256[] memory) {
        require(_source != _destination, "The starting and ending points should be different");

        // 符合条件的订单数量，也可作为索引使用，反正从0开始的
        uint256 count = 0;
        // 临时数组，用于存储符合条件的ID
        uint256[] memory bookingOpenIdsTemp = new uint256[](bookingOpenIds.length);

        for (uint256 i = 0; i < bookingOpenIds.length; i++) {
            Ride storage ride = rides[bookingOpenIds[i]];
            if (ride.origin == _source && ride.destination == _destination && ride.status == RideStatus.BookingOpen) {
                // 将符合条件的ID放入临时数组
                bookingOpenIdsTemp[count] = ride.rideId;
                count++;
            }  
        }  

        // 如果没有找到符合条件的订单，则直接返回空数组
        if (count == 0) {
            return new uint256[](0);
        }
    
        // 最终的订单ID数组
        uint256[] memory rideIds = new uint256[](count);

        // 将临时数组中的ID复制到最终数组
        for (uint256 i = 0; i < count; i++) {
            rideIds[i] = bookingOpenIdsTemp[i];
        }

        // 使用冒泡排序对rideIds按照travelTime进行排序
        for (uint256 i = 0; i < count - 1; i++) {
            for (uint256 j = 0; j < count - i - 1; j++) {
                Ride storage rideJ = rides[rideIds[j]];
                Ride storage rideJPlusOne = rides[rideIds[j + 1]];
                if (rideJ.travelTime > rideJPlusOne.travelTime) {
                    // 交换rideIds中的元素
                    uint256 temp = rideIds[j];
                    rideIds[j] = rideIds[j + 1];
                    rideIds[j + 1] = temp;
                }
            }
        }

        // 返回排序后的订单ID数组
        return rideIds;
    }

    // 乘客拼车
    function joinRide(uint256 _rideId) public payable onlyPassenger passengerSingleRide{
        // 校验订单ID，不能超过当前最大订单ID
        require(_rideId <= nextId, "rideId does not exist");
        // 支付金额必须等于单价
        require(msg.value == rides[_rideId].seatPrice, "Carpool price must be correct");
        // 乘客不能同时拼多个车
        require(passengers[msg.sender].hasRide == false, "A passenger cannot join multiple rides simultaneously");
        // 拿到订单信息
        Ride storage ride = rides[_rideId];
        // 订单状态必须是BookingOpen
        require(ride.status == RideStatus.BookingOpen, "Carpool status must be BookingOpen");
        // 剩余座位数量必须大于0
        require(ride.availableSeats > 0, "There must be remaining seats in the ride");

        // 变更乘客拼车状态
        passengers[msg.sender].hasRide = true;
        // 记录乘客地址
        ride.passengerAddr.push(msg.sender);
        
        // 如果是最后一个座位
        if (ride.availableSeats == 1) {
            // 变更订单状态：已满
            ride.status = RideStatus.FullyBooked;
            // 从bookingOpenIds中移除此ID
            for (uint256 i = 0; i < bookingOpenIds.length; i++) {
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
        
        // 触发乘客拼车事件
        emit RideJoined(_rideId, msg.sender);
    }

    // 司机发车
    function startRide(uint256 _rideId) public onlyDriver{
        // 获取拼车订单信息
        Ride storage ride = rides[_rideId];
        // 订单状态必须是：FullyBooked
        require(ride.status == RideStatus.FullyBooked, "The order status must be FullyBooked");
        // 司机只能操作自己的订单
        require(ride.driver == msg.sender, "The driver can only start his own ride");

        // 变更订单状态为已发车
        ride.status = RideStatus.Started;
        // 触发司机发车事件
        emit RideStarted(_rideId);
    }

    // 司机完成订单
    // 不用考虑重入攻击，因为ride.status有状态改变，函数无法被同一个_rideId反复触发
    function completeRide(uint256 _rideId) public onlyDriver{
        // 获取拼车订单信息
        Ride storage ride = rides[_rideId];
        // 订单状态必须是：Started
        require(ride.status == RideStatus.Started, "The order status must be Started");
        // 司机只能操作自己的订单
        require(ride.driver == msg.sender, "The driver can only start his own ride");

        // 变更订单状态为已完成
        ride.status = RideStatus.Completed;
        // 变更司机状态
        drivers[msg.sender].hasRide = false;
        // 变更全车乘客状态
        for (uint i = 0;i < ride.passengerAddr.length;i++) {
            passengers[ride.passengerAddr[i]].hasRide = false;
        }

        // 司机获得收益 = 人数 * 单价
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

    // 等待协调结构体
    struct PassengerWaitlist {
        // 等待协调ID
        uint256 awaitId;
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
        // 是否已协调
        bool isAssigned;
    }

    // 等待协调唯一ID
    uint nextAwaitId;

    // 等待数据列表映射
    mapping(uint => PassengerWaitlist) public passengerWaitlist;

    // 等待的ID组
    // 比使用PassengerWaitlist[]好，gas消耗更少
    uint[] awaitIds;

    // 等待协调事件
    event AwaitAssignRideJoined(address passenger);

    // 乘客选择等待协调
    function awaitAssignRide(Location _source, Location _destination, uint8 _preferredTravelTime) public payable onlyPassenger {
        // 文中说：假设协调的乘客总是支付足够的押金，足以加入任何乘车（因此在协调乘车时不需要考虑这个因素），简单校验下即可
        require(msg.value > 0, "Insufficient deposit");
        // 文中说：一个乘客不能两次调用awaitAssignRide
        // 另外也需要考虑：一个乘客不能joinRide的同时又awaitAssignRide，所以hasRide来处理刚好
        require(passengers[msg.sender].hasRide == false, "Passenger has already joined a ride and cannot join another");

        // 加入等待协调的列表
        passengerWaitlist[nextAwaitId] = PassengerWaitlist({
            awaitId: nextAwaitId,
            passenger: msg.sender,
            source: _source,
            destination: _destination,
            preferredTravelTime: _preferredTravelTime,
            deposit: msg.value,
            isAssigned: false
        });

        // push到等待的ID组
        awaitIds.push(nextAwaitId);

        // 改变乘客状态
        passengers[msg.sender].hasRide == true;

        // 触发加入等待协调事件
        emit AwaitAssignRideJoined(msg.sender);

        // 等待协调唯一ID自增
        nextAwaitId++;
    }

    // 系统为乘客分配乘车
    // 目标是最小化乘客的首选和实际旅行时间偏差的差异之和
    // 解决办法：先按乘客期望时间排序，再按司机发车时间排序，然后一一匹配，就能实现最小化差异之和了
    function assignPassengersToRides() public {
        // Your implementation here
    }
}