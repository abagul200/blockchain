// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title EduChain
 * @dev A decentralized educational platform for credential verification and course management
 */
contract EduChain {
    
    // State variables
    address public owner;
    uint256 public totalCourses;
    uint256 public totalStudents;
    
    // Structs
    struct Course {
        uint256 courseId;
        string title;
        string description;
        address instructor;
        uint256 price;
        uint256 duration; // in days
        bool isActive;
        uint256 enrolledStudents;
        uint256 createdAt;
    }
    
    struct Student {
        address studentAddress;
        string name;
        uint256[] enrolledCourses;
        uint256[] completedCourses;
        uint256 totalCredits;
        bool isRegistered;
        uint256 registeredAt;
    }
    
    struct Certificate {
        uint256 certificateId;
        uint256 courseId;
        address student;
        address instructor;
        uint256 issuedAt;
        string certificateHash; // IPFS hash for certificate document
        bool isVerified;
    }
    
    // Mappings
    mapping(uint256 => Course) public courses;
    mapping(address => Student) public students;
    mapping(uint256 => Certificate) public certificates;
    mapping(address => mapping(uint256 => bool)) public enrollments;
    mapping(address => bool) public authorizedInstructors;
    
    // Events
    event StudentRegistered(address indexed student, string name, uint256 timestamp);
    event CourseCreated(uint256 indexed courseId, string title, address indexed instructor, uint256 price);
    event StudentEnrolled(address indexed student, uint256 indexed courseId, uint256 timestamp);
    event CertificateIssued(uint256 indexed certificateId, uint256 indexed courseId, address indexed student);
    event InstructorAuthorized(address indexed instructor, uint256 timestamp);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyAuthorizedInstructor() {
        require(authorizedInstructors[msg.sender], "Only authorized instructors can call this function");
        _;
    }
    
    modifier onlyRegisteredStudent() {
        require(students[msg.sender].isRegistered, "Student must be registered");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        totalCourses = 0;
        totalStudents = 0;
    }
    
    /**
     * @dev Core Function 1: Register Student
     * @param _name Student's name
     */
    function registerStudent(string memory _name) public {
        require(!students[msg.sender].isRegistered, "Student already registered");
        require(bytes(_name).length > 0, "Name cannot be empty");
        
        students[msg.sender] = Student({
            studentAddress: msg.sender,
            name: _name,
            enrolledCourses: new uint256[](0),
            completedCourses: new uint256[](0),
            totalCredits: 0,
            isRegistered: true,
            registeredAt: block.timestamp
        });
        
        totalStudents++;
        emit StudentRegistered(msg.sender, _name, block.timestamp);
    }
    
    /**
     * @dev Core Function 2: Create Course
     * @param _title Course title
     * @param _description Course description
     * @param _price Course price in wei
     * @param _duration Course duration in days
     */
    function createCourse(
        string memory _title,
        string memory _description,
        uint256 _price,
        uint256 _duration
    ) public onlyAuthorizedInstructor {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_duration > 0, "Duration must be greater than 0");
        
        totalCourses++;
        
        courses[totalCourses] = Course({
            courseId: totalCourses,
            title: _title,
            description: _description,
            instructor: msg.sender,
            price: _price,
            duration: _duration,
            isActive: true,
            enrolledStudents: 0,
            createdAt: block.timestamp
        });
        
        emit CourseCreated(totalCourses, _title, msg.sender, _price);
    }
    
    /**
     * @dev Core Function 3: Issue Certificate
     * @param _courseId Course ID for which certificate is being issued
     * @param _student Student address
     * @param _certificateHash IPFS hash of the certificate document
     */
    function issueCertificate(
        uint256 _courseId,
        address _student,
        string memory _certificateHash
    ) public onlyAuthorizedInstructor {
        require(_courseId <= totalCourses && _courseId > 0, "Invalid course ID");
        require(courses[_courseId].instructor == msg.sender, "Only course instructor can issue certificate");
        require(students[_student].isRegistered, "Student must be registered");
        require(enrollments[_student][_courseId], "Student must be enrolled in the course");
        require(bytes(_certificateHash).length > 0, "Certificate hash cannot be empty");
        
        uint256 certificateId = uint256(keccak256(abi.encodePacked(_student, _courseId, block.timestamp)));
        
        certificates[certificateId] = Certificate({
            certificateId: certificateId,
            courseId: _courseId,
            student: _student,
            instructor: msg.sender,
            issuedAt: block.timestamp,
            certificateHash: _certificateHash,
            isVerified: true
        });
        
        // Add course to completed courses if not already added
        bool alreadyCompleted = false;
        for (uint i = 0; i < students[_student].completedCourses.length; i++) {
            if (students[_student].completedCourses[i] == _courseId) {
                alreadyCompleted = true;
                break;
            }
        }
        
        if (!alreadyCompleted) {
            students[_student].completedCourses.push(_courseId);
            students[_student].totalCredits += 10; // Award 10 credits per completed course
        }
        
        emit CertificateIssued(certificateId, _courseId, _student);
    }
    
    // Additional utility functions
    
    /**
     * @dev Enroll student in a course
     * @param _courseId Course ID to enroll in
     */
    function enrollInCourse(uint256 _courseId) public payable onlyRegisteredStudent {
        require(_courseId <= totalCourses && _courseId > 0, "Invalid course ID");
        require(courses[_courseId].isActive, "Course is not active");
        require(!enrollments[msg.sender][_courseId], "Already enrolled in this course");
        require(msg.value >= courses[_courseId].price, "Insufficient payment");
        
        enrollments[msg.sender][_courseId] = true;
        students[msg.sender].enrolledCourses.push(_courseId);
        courses[_courseId].enrolledStudents++;
        
        // Transfer payment to instructor
        if (courses[_courseId].price > 0) {
            payable(courses[_courseId].instructor).transfer(courses[_courseId].price);
        }
        
        // Refund excess payment
        if (msg.value > courses[_courseId].price) {
            payable(msg.sender).transfer(msg.value - courses[_courseId].price);
        }
        
        emit StudentEnrolled(msg.sender, _courseId, block.timestamp);
    }
    
    /**
     * @dev Authorize an instructor
     * @param _instructor Address of the instructor to authorize
     */
    function authorizeInstructor(address _instructor) public onlyOwner {
        require(_instructor != address(0), "Invalid instructor address");
        authorizedInstructors[_instructor] = true;
        emit InstructorAuthorized(_instructor, block.timestamp);
    }
    
    /**
     * @dev Verify a certificate
     * @param _certificateId Certificate ID to verify
     */
    function verifyCertificate(uint256 _certificateId) public view returns (
        bool isValid,
        uint256 courseId,
        address student,
        address instructor,
        uint256 issuedAt,
        string memory certificateHash
    ) {
        Certificate memory cert = certificates[_certificateId];
        return (
            cert.isVerified,
            cert.courseId,
            cert.student,
            cert.instructor,
            cert.issuedAt,
            cert.certificateHash
        );
    }
    
    /**
     * @dev Get student's enrolled courses
     * @param _student Student address
     */
    function getStudentEnrolledCourses(address _student) public view returns (uint256[] memory) {
        return students[_student].enrolledCourses;
    }
    
    /**
     * @dev Get student's completed courses
     * @param _student Student address
     */
    function getStudentCompletedCourses(address _student) public view returns (uint256[] memory) {
        return students[_student].completedCourses;
    }
    
    /**
     * @dev Get course details
     * @param _courseId Course ID
     */
    function getCourseDetails(uint256 _courseId) public view returns (
        string memory title,
        string memory description,
        address instructor,
        uint256 price,
        uint256 duration,
        bool isActive,
        uint256 enrolledStudents
    ) {
        Course memory course = courses[_courseId];
        return (
            course.title,
            course.description,
            course.instructor,
            course.price,
            course.duration,
            course.isActive,
            course.enrolledStudents
        );
    }
    
    /**
     * @dev Emergency function to pause/unpause a course
     * @param _courseId Course ID
     * @param _isActive New active status
     */
    function setCourseStatus(uint256 _courseId, bool _isActive) public {
        require(_courseId <= totalCourses && _courseId > 0, "Invalid course ID");
        require(
            msg.sender == courses[_courseId].instructor || msg.sender == owner,
            "Only course instructor or owner can change status"
        );
        
        courses[_courseId].isActive = _isActive;
    }
    
    /**
     * @dev Get contract statistics
     */
    function getContractStats() public view returns (
        uint256 _totalCourses,
        uint256 _totalStudents,
        address _owner
    ) {
        return (totalCourses, totalStudents, owner);
    }
}
