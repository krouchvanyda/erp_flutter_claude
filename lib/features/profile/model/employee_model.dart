/// My employee record, from `GET /api/v1/employees/me`
/// (fields from API_LIST_BACKEND.md §5).
///
/// Not every user has one: the server answers 404 when the login user has
/// no linked employee. So everything except [id] is nullable.
class EmployeeModel {
  const EmployeeModel({
    required this.id,
    this.employeeNo,
    this.fullName,
    this.workEmail,
    this.phone,
    this.position,
    this.department,
    this.hireDate,
    this.dateOfBirth,
    this.gender,
    this.address,
    this.avatarUrl,
    this.emergencyContact,
    this.emergencyPhone,
    this.status,
  });

  final String id;
  final String? employeeNo;
  final String? fullName;
  final String? workEmail;
  final String? phone;
  final String? position;
  final String? department;
  final DateTime? hireDate; // "YYYY-MM-DD" on the wire
  final DateTime? dateOfBirth;
  final String? gender;
  final String? address;
  final String? avatarUrl; // "/uploads/..." or null
  final String? emergencyContact;
  final String? emergencyPhone;

  /// EmployeeStatus: ACTIVE, INACTIVE, ON_LEAVE, TERMINATED.
  final String? status;

  factory EmployeeModel.fromJson(Map<String, dynamic> json) => EmployeeModel(
    id: '${json['id'] ?? ''}', // a number on the wire → String in the app
    employeeNo: json['employeeNo'] as String?,
    fullName: json['fullName'] as String?,
    workEmail: json['workEmail'] as String?,
    phone: json['phone'] as String?,
    position: json['position'] as String?,
    department: json['department'] as String?,
    hireDate: DateTime.tryParse(json['hireDate'] as String? ?? ''),
    dateOfBirth: DateTime.tryParse(json['dateOfBirth'] as String? ?? ''),
    gender: json['gender'] as String?,
    address: json['address'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    emergencyContact: json['emergencyContact'] as String?,
    emergencyPhone: json['emergencyPhone'] as String?,
    status: json['status'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is EmployeeModel &&
      other.id == id &&
      other.employeeNo == employeeNo &&
      other.fullName == fullName &&
      other.workEmail == workEmail &&
      other.phone == phone &&
      other.position == position &&
      other.department == department &&
      other.hireDate == hireDate &&
      other.dateOfBirth == dateOfBirth &&
      other.gender == gender &&
      other.address == address &&
      other.avatarUrl == avatarUrl &&
      other.emergencyContact == emergencyContact &&
      other.emergencyPhone == emergencyPhone &&
      other.status == status;

  // Object.hash takes up to 20 values.
  @override
  int get hashCode => Object.hash(
    id,
    employeeNo,
    fullName,
    workEmail,
    phone,
    position,
    department,
    hireDate,
    dateOfBirth,
    gender,
    address,
    avatarUrl,
    emergencyContact,
    emergencyPhone,
    status,
  );

  /// No address, phones or birth date in logs (private data).
  @override
  String toString() => 'EmployeeModel($id, $employeeNo)';
}
