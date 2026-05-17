import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'services/session.dart';

const String API_URL = 'http://167.99.113.105:8080';

Future<Map<String, String>> _authHeaders([Map<String, String>? extra]) async {
  final token = await Session.getAccessToken();
  final base = <String, String>{
    'Content-Type': 'application/json',
    'X-Client-Type': 'mobile',
    if (token != null) 'Authorization': 'Bearer $token',
  };
  if (extra != null) base.addAll(extra);
  return base;
}

Map<String, String> _publicHeaders([Map<String, String>? extra]) {
  final base = <String, String>{
    'Content-Type': 'application/json',
    'X-Client-Type': 'mobile',
  };
  if (extra != null) base.addAll(extra);
  return base;
}

Future<Map<String, String>> _authHeadersNoContentType() async {
  final token = await Session.getAccessToken();
  return {
    'X-Client-Type': 'mobile',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}

// Register
Future<http.Response> signupUser(Map<String, dynamic> userData) async {
  try {
    final response = await http.post(
      Uri.parse('$API_URL/register'),
      headers: _publicHeaders(),
      body: jsonEncode(userData),
    );

    return response;
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Login
Future<http.Response> loginUser(Map<String, dynamic> userData) async {
  try {
    print('API: Login request - username: ${userData['username']}, password length: ${userData['password']?.toString().length ?? 0}');
    
    final response = await http.post(
      Uri.parse('$API_URL/login'),
      headers: _publicHeaders(),
      body: jsonEncode(userData),
    );

    print('API: Login response status: ${response.statusCode}');
    print('API: Login response body: ${response.body}');
    
    // If 401, try to parse error message
    if (response.statusCode == 401) {
      try {
        final errorData = jsonDecode(response.body);
        print('API: Login failed - Error details: $errorData');
        print('API: Error message: ${errorData['message'] ?? errorData['error'] ?? 'Unauthorized'}');
      } catch (e) {
        print('API: Login failed - Could not parse error response: ${response.body}');
      }
    }

    return response;
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

Future<Map<String, dynamic>> sendEmailOtp(String tempToken) async {
  try {
    final response = await http.post(
      Uri.parse('$API_URL/mfa/send-email-otp'),
      headers: _publicHeaders(),
      body: jsonEncode({'tempToken': tempToken}),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

Future<Map<String, dynamic>> verifyMfaLogin({
  required String tempToken,
  required String token,
  required String method,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$API_URL/mfa/verify-login'),
      headers: _publicHeaders(),
      body: jsonEncode({'tempToken': tempToken, 'token': token, 'method': method}),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

Future<http.Response> checkstatus(int userid) async {
  try {
    final response = await http.get(
      Uri.parse('$API_URL/checkStatus?userid=$userid'),
      headers: await _authHeaders(),
    );
    return response;
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Logout
Future<Map<String, dynamic>> logoutUser(int userid) async {
  try {
    final refreshToken = await Session.getRefreshToken();
    final response = await http.post(
      Uri.parse('$API_URL/logout'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'userid': userid,
        if (refreshToken != null) 'refreshToken': refreshToken,
      }),
    );
    await Session.clear();
    final responseData = jsonDecode(response.body);
    return responseData;
  } catch (error) {
    print('API error: $error');
    await Session.clear();
    rethrow;
  }
}

// Properties Listing
Future<Map<String, dynamic>> propertiesListing(dynamic propertyData) async {
  final usergroup = await Session.getUserGroup();
  
  try {
    final response = await http.post(
      Uri.parse('$API_URL/propertiesListing'),
      headers: await _authHeadersNoContentType(),
      body: propertyData,
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['error'] ?? 'Failed to create property');
    }

    final responseData = jsonDecode(response.body);
    return responseData;
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Fetch Properties (Product) - can return a List or Map depending on backend
Future<dynamic> fetchProduct() async {
  try {
    final response = await http.get(Uri.parse('$API_URL/product'));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch properties');
    }
    final dynamic data = jsonDecode(response.body);
    return data; 
  } catch (error) {
    print('Error fetching properties: $error');
    rethrow;
  }
}

// Fetch single property details with ALL images
Future<Map<String, dynamic>> fetchSinglePropertyDetails(int propertyId) async {
  final uri = Uri.parse('$API_URL/property/$propertyId');

  print('API: Fetch single property details URL: $uri');

  final response = await http.get(
    uri,
    headers: await _authHeaders(),
  );

  print('API: Fetch single property details status: ${response.statusCode}');
  print('API: Fetch single property details body: ${response.body}');

  if (response.statusCode != 200) {
    throw Exception('Failed to fetch property details');
  }

  final data = jsonDecode(response.body);

  if (data is Map && data['property'] is Map) {
    return Map<String, dynamic>.from(data['property']);
  }

  throw Exception('Invalid property details response');
}

Future<Map<String, dynamic>> fetchPropertyAvailability({
  required int propertyId,
  required String checkIn,
  required String checkOut,
  String roomName = '',
  String packageName = '',
}) async {
  final uri = Uri.parse('$API_URL/property-availability').replace(
    queryParameters: {
      'propertyid': propertyId.toString(),
      'checkIn': checkIn,
      'checkOut': checkOut,
      if (roomName.trim().isNotEmpty) 'roomName': roomName.trim(),
      if (packageName.trim().isNotEmpty) 'packageName': packageName.trim(),
    },
  );

  final response = await http.get(
    uri,
    headers: await _authHeaders(),
  );

  final data = jsonDecode(response.body);

  if (response.statusCode != 200) {
    throw Exception(data['message'] ?? 'Failed to check property availability');
  }

  return data;
}

// Fetch Properties (Dashboard)
Future<Map<String, dynamic>> fetchPropertiesListingTable() async {
  final username = await Session.getUsername();
  final usergroup = await Session.getUserGroup();
  
  if (username == null) {
    print('API: Username not found in session, returning empty properties');
    return {'properties': []};
  }
  
  try {
    // Build query parameters
    // For admin/moderator, include allStatuses=true to get all properties (pending, approved, rejected)
    final isAdminOrModerator = usergroup != null && 
        (usergroup.toLowerCase() == 'admin' || 
         usergroup.toLowerCase() == 'administrator' || 
         usergroup.toLowerCase() == 'moderator');
    
    // For admin: get all properties (don't filter by username)
    // For moderator: get all their properties (filter by creator, not username)
    // For customer: filter by username and only available properties
    var queryParams = <String, String>{};
    
    if (isAdminOrModerator) {
      // Admin/moderator should see all properties they created or are responsible for
      // Backend requires username parameter, so we must send it
      queryParams['username'] = username;
      queryParams['usergroup'] = usergroup!;
      queryParams['allStatuses'] = 'true';
      // For admin, also request all properties (not just their own)
      if (usergroup!.toLowerCase() == 'admin' || usergroup.toLowerCase() == 'administrator') {
        queryParams['includeAll'] = 'true'; // Request all properties for admin
        queryParams['includeAllClusters'] = 'true'; // Include all clusters (don't filter by clusterid)
        queryParams['includeAllCategories'] = 'true'; // Include all categories (don't filter by categoryid)
      }
    } else {
      // Customer: filter by username only
      queryParams['username'] = username;
    }
    
    final queryString = queryParams.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
    
    print('API: Fetching properties for username: $username, usergroup: $usergroup');
    print('API: Query params: $queryString');
    final response = await http.get(
      Uri.parse('$API_URL/propertiesListingTable?$queryString'),
      headers: await _authHeaders(),
    );

    print('API: Properties response status: ${response.statusCode}');
    print('API: Properties response body: ${response.body}');

    // Handle 404 as "no properties found"
    if (response.statusCode == 404) {
      print('API: No properties found for user (404), returning empty list');
      return {'properties': []};
    }
    
    if (response.statusCode != 200) {
      print('API: Error status ${response.statusCode}, returning empty list');
      return {'properties': []};
    }

    final data = jsonDecode(response.body);
    print('API: Properties data structure - keys: ${data.keys.toList()}');
    
    // Debug: Log all properties with their clusterid and categoryid
    if (data['properties'] != null && data['properties'] is List) {
      final props = data['properties'] as List;
      print('API: Total properties returned: ${props.length}');
      for (var i = 0; i < props.length; i++) {
        final prop = props[i] as Map<String, dynamic>;
        print('API: Property ${i + 1}:');
        print('   propertyid: ${prop['propertyid']}');
        print('   propertyaddress: ${prop['propertyaddress']}');
        print('   userid: ${prop['userid']}');
        print('   clusterid: ${prop['clusterid']}');
        print('   categoryid: ${prop['categoryid']}');
        print('   propertystatus: ${prop['propertystatus']}');
      }
    }
    
    return data; 
  } catch (error) {
    print('Error fetching properties: $error');
    // Return empty instead of throwing
    return {'properties': []};
  }
}

Future<Map<String, dynamic>> createPropertyListing({
  required String username,
  required String propertyName,
  required String location,
  required double price,
  double? promoPrice,
  required List<Uint8List> imageBytes,
  String categoryName = 'Homestay', // Default category, can be overridden
}) async {
  try {
    // Get creator information from session
    final creatorid = await Session.getUserId();
    final creatorUsername = username;
    final usergroup = await Session.getUserGroup();
    
    // Build URI with query parameters for creator information
    final queryParams = <String, String>{};
    if (creatorid != null) {
      queryParams['creatorid'] = creatorid.toString();
      queryParams['creatorUsername'] = creatorUsername;
    }
    if (usergroup != null) {
      queryParams['usergroup'] = usergroup;
    }
    
    final uri = Uri.parse('$API_URL/propertiesListing').replace(queryParameters: queryParams);
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _authHeadersNoContentType());

    final formattedPrice = price.toStringAsFixed(2);
    final formattedPromo =
        (promoPrice ?? price).clamp(0, double.infinity).toStringAsFixed(2);

    // Determine property status based on user role
    // Admin-created properties should be "Available" immediately
    // Moderator-created properties should be "Pending" (need admin approval)
    final isAdmin = usergroup != null && 
        (usergroup.toLowerCase() == 'admin' || usergroup.toLowerCase() == 'administrator');
    final propertyStatus = isAdmin ? 'Available' : 'Pending';
    
    // Dynamically fetch the cluster name that corresponds to clusterid=1
    // This ensures we use the correct cluster name even if clusters are renamed or reorganized
    String clusterName;
    try {
      final clustersData = await fetchClusters();
      
      // Handle different response formats
      // fetchClusters() always returns Map<String, dynamic>, so we extract the 'clusters' key
      List<dynamic> clusters = [];
      if (clustersData is Map) {
        final clustersKey = clustersData['clusters'];
        if (clustersKey != null && clustersKey is List) {
          clusters = clustersKey as List<dynamic>;
        }
      }
      
      print('API: Fetched ${clusters.length} clusters');
      
      // Find the cluster with clusterid=1 (handle both int and string)
      Map<String, dynamic>? targetCluster;
      for (var cluster in clusters) {
        if (cluster is! Map<String, dynamic>) continue;
        
        final clusterId = cluster['clusterid'] ?? cluster['clusterId'] ?? cluster['id'];
        if (clusterId == 1 || clusterId == '1' || clusterId.toString() == '1') {
          targetCluster = cluster;
          break;
        }
      }
      
      if (targetCluster != null) {
        clusterName = targetCluster['clustername']?.toString() ?? 
                     targetCluster['clusterName']?.toString() ?? 
                     targetCluster['name']?.toString() ??
                     'Default Cluster';
        print('API: Found cluster for clusterid=1: $clusterName');
      } else {
        // Fallback: try to get the first cluster, or use a default
        if (clusters.isNotEmpty && clusters[0] is Map<String, dynamic>) {
          final firstCluster = clusters[0] as Map<String, dynamic>;
          clusterName = firstCluster['clustername']?.toString() ?? 
                       firstCluster['clusterName']?.toString() ?? 
                       firstCluster['name']?.toString() ??
                       'Default Cluster';
          print('API: Cluster with clusterid=1 not found, using first available cluster: $clusterName');
        } else {
          throw Exception('No clusters found in database. Please ensure at least one cluster exists.');
        }
      }
    } catch (error) {
      print('API: Error fetching cluster name: $error');
      // If cluster fetch fails, throw an error to prevent creating property with wrong cluster
      throw Exception('Failed to fetch cluster information: ${error.toString()}. Please try again or contact support.');
    }
    
    request.fields.addAll({
      'username': username,
      'propertyPrice': formattedPrice,
      'propertyAddress': propertyName,
      'clusterName': clusterName, // Use dynamically fetched cluster name for clusterid=1
      'categoryName': categoryName, // Use the selected category from dropdown
      // Explicitly set clusterid and categoryid to 1 to match website-created properties
      'clusterid': '1',
      'categoryid': '1',
      'propertyBedType': '1',
      'propertyGuestPaxNo': '2',
      'propertyDescription':
          'Listing created from mobile app for $propertyName',
      'nearbyLocation': location.isEmpty ? 'Not specified' : location,
      'facilities': 'WiFi,Parking',
      'weekendRate': formattedPrice,
      'specialEventRate': formattedPrice,
      'earlyBirdDiscountRate': formattedPromo,
      'lastMinuteDiscountRate': formattedPromo,
      'isSpecialEventEnabled': 'false',
      // Try both field name variations - backend might expect lowercase
      'propertyStatus': propertyStatus,
      'propertystatus': propertyStatus,
      // Also include userid in fields if available
      if (creatorid != null) 'userid': creatorid.toString(),
      // Add creator information in request body fields (backend might need this)
      if (creatorid != null) 'creatorid': creatorid.toString(),
      'creatorUsername': creatorUsername,
      if (usergroup != null) 'creatorusergroup': usergroup,
      if (usergroup != null) 'creatorUserGroup': usergroup, // Try both cases
    });
    
    print('API: Creating property with creatorid: $creatorid, creatorUsername: $creatorUsername, usergroup: $usergroup, status: $propertyStatus');
    print('API: Setting clusterid=1 and categoryid=1 to match website-created properties');
    print('API: Request fields: ${request.fields}');
    print('API: Request URL: ${request.url}');
    print('API: Query parameters: ${uri.queryParameters}');

    if (imageBytes.isEmpty) {
      throw Exception('At least one image is required');
    }
    final imagesToUpload = imageBytes.take(10).toList();
    for (int i = 0; i < imagesToUpload.length; i++) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'propertyImage',
          imagesToUpload[i],
          filename: 'image_$i.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    print('API: Create property response status: ${response.statusCode}');
    print('API: Create property response body: ${response.body}');

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          'Failed to create property (${response.statusCode}): ${response.body}');
    }

    final responseData = jsonDecode(response.body);
    print('API: Create property response data: $responseData');
    return responseData;
  } catch (error) {
    print('API error creating property: $error');
    rethrow;
  }
}

// Update Property
Future<Map<String, dynamic>> updateProperty(dynamic propertyData, int propertyid) async {
  final creatorid = await Session.getUserId();
  final username = 'user_${creatorid ?? 0}'; // TODO: Get actual username from session
  final creatorUsername = username;
  
  if (propertyid == 0) {
    throw Exception('propertyid invalid');
  }
  
  try {
    final response = await http.put(
      Uri.parse('$API_URL/propertiesListing/$propertyid?creatorid=$creatorid&creatorUsername=$creatorUsername'),
      headers: await _authHeadersNoContentType(),
      body: propertyData,
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['error'] ?? 'Failed to update property');
    }

    return jsonDecode(response.body);
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Update property status
Future<Map<String, dynamic>> updatePropertyStatus(
    int propertyid, String status) async {

  final creatorid = await Session.getUserId();
  final creatorUsername = await Session.getUsername();

  if (creatorid == null || creatorUsername == null) {
    throw Exception('User not logged in');
  }

  try {
    final uri = Uri.parse('$API_URL/updatePropertyStatus/$propertyid')
        .replace(queryParameters: {
      'creatorid': creatorid.toString(),
      'creatorUsername': creatorUsername,
    });

    final response = await http.patch(
      uri,
      headers: await _authHeaders(),
      body: jsonEncode({'propertyStatus': status}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Failed to update property status');
    }

    return data;
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Delete Property
Future<Map<String, dynamic>> deleteProperty(int propertyid) async {
  final creatorid = await Session.getUserId();
  final creatorUsername = await Session.getUsername();
  
  if (creatorid == null || creatorUsername == null) {
    throw Exception('User session not found. Please log in again.');
  }
  
  try {
    final response = await http.delete(
      Uri.parse('$API_URL/removePropertiesListing/$propertyid?creatorid=$creatorid&creatorUsername=$creatorUsername'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['error'] ?? errorData['message'] ?? 'Failed to delete property');
    }

    return jsonDecode(response.body);
  } catch (error) {
    print('API error deleting property: $error');
    rethrow;
  }
}

// Fetch Customers
Future<Map<String, dynamic>> fetchCustomers() async {
  final userid = await Session.getUserId();
  
  try {
    print('API: Fetching customers... (userid: $userid, timestamp: ${DateTime.now().millisecondsSinceEpoch})');
    final response = await http.get(
      Uri.parse('$API_URL/users/customers?userid=$userid&_t=${DateTime.now().millisecondsSinceEpoch}'),
      headers: await _authHeaders({
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      }),
    );

    print('API: Customers response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      print('API: Error fetching customers, returning empty');
      return {'customers': []};
    }

    final decoded = jsonDecode(response.body);
    
    // Handle both List and Map responses
    if (decoded is List) {
      print('API: Customers returned as List with ${decoded.length} items');
      return {'customers': decoded};
    } else if (decoded is Map) {
      print('API: Customers data keys: ${(decoded as Map).keys.toList()}');
      return decoded as Map<String, dynamic>;
    }
    
    return {'customers': []};
  } catch (error) {
    print('API error fetching customers: $error');
    return {'customers': []};
  }
}

// Fetch Owners
Future<Map<String, dynamic>> fetchOwners() async {
  try {
    print('API: Fetching owners... (timestamp: ${DateTime.now().millisecondsSinceEpoch})');
    final response = await http.get(
      Uri.parse('$API_URL/users/owners?_t=${DateTime.now().millisecondsSinceEpoch}'),
      headers: await _authHeaders({
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      }),
    );

    print('API: Owners response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      print('API: Error fetching owners, returning empty');
      return {'owners': []};
    }

    final decoded = jsonDecode(response.body);
    
    // Handle both List and Map responses
    if (decoded is List) {
      print('API: Owners returned as List with ${decoded.length} items');
      return {'owners': decoded};
    } else if (decoded is Map) {
      print('API: Owners data keys: ${(decoded as Map).keys.toList()}');
      return decoded as Map<String, dynamic>;
    }
    
    return {'owners': []};
  } catch (error) {
    print('API error fetching owners: $error');
    return {'owners': []};
  }
}

// Fetch Moderators
Future<Map<String, dynamic>> fetchModerators() async {
  final userid = await Session.getUserId();
  
  try {
    print('API: Fetching moderators... (userid: $userid, timestamp: ${DateTime.now().millisecondsSinceEpoch})');
    final response = await http.get(
      Uri.parse('$API_URL/users/moderators?userid=$userid&_t=${DateTime.now().millisecondsSinceEpoch}'),
      headers: await _authHeaders({
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      }),
    );

    print('API: Moderators response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      print('API: Error fetching moderators, returning empty');
      return {'moderators': []};
    }

    final decoded = jsonDecode(response.body);
    
    // Handle both List and Map responses
    if (decoded is List) {
      print('API: Moderators returned as List with ${decoded.length} items');
      return {'moderators': decoded};
    } else if (decoded is Map) {
      print('API: Moderators data keys: ${(decoded as Map).keys.toList()}');
      return decoded as Map<String, dynamic>;
    }
    
    return {'moderators': []};
  } catch (error) {
    print('API error fetching moderators: $error');
    return {'moderators': []};
  }
}

// Fetch Operators
Future<Map<String, dynamic>> fetchOperators() async {
  try {
    final response = await http.get(
      Uri.parse('$API_URL/users/operators'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch operators');
    }

    return jsonDecode(response.body);
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Fetch Administrator
Future<Map<String, dynamic>> fetchAdministrators() async {
  try {
    print('API: Fetching administrators... (timestamp: ${DateTime.now().millisecondsSinceEpoch})');
    final response = await http.get(
      Uri.parse('$API_URL/users/administrators?_t=${DateTime.now().millisecondsSinceEpoch}'),
      headers: await _authHeaders({
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      }),
    );

    print('API: Administrators response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      print('API: Error fetching administrators, returning empty');
      return {'administrators': []};
    }

    final decoded = jsonDecode(response.body);
    
    // Handle both List and Map responses
    if (decoded is List) {
      print('API: Administrators returned as List with ${decoded.length} items');
      return {'administrators': decoded};
    } else if (decoded is Map) {
      print('API: Administrators data keys: ${(decoded as Map).keys.toList()}');
      return decoded as Map<String, dynamic>;
    }
    
    return {'administrators': []};
  } catch (error) {
    print('API error fetching administrators: $error');
    return {'administrators': []};
  }
}

// Create Moderator
Future<http.Response> createModerator(Map<String, dynamic> userData) async {
  try {
    final response = await http.post(
      Uri.parse('$API_URL/users/createModerator'),
      headers: await _authHeaders(),
      body: jsonEncode(userData),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create moderator');
    }

    return response;
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Update User
Future<Map<String, dynamic>> updateUser(Map<String, dynamic> userData, int userid) async {
  try {
    final url = '$API_URL/users/updateUser/$userid';

    final response = await http.put(
      Uri.parse(url),
      headers: await _authHeaders(),
      body: jsonEncode(userData),
    );

    if (response.statusCode != 200) {
      try {
        final errorText = response.body;
        
        try {
          final errorData = jsonDecode(errorText) as Map<String, dynamic>;
          throw Exception(errorData['error'] ?? errorData['message'] ?? 'Failed to update user (${response.statusCode})');
        } catch (jsonError) {
          // Response is not valid JSON
          throw Exception('Server error (${response.statusCode}): ${errorText.isNotEmpty ? errorText : response.reasonPhrase}');
        }
      } catch (parseError) {
        // Error parsing response
        throw Exception('Failed to update user: ${response.statusCode} ${response.reasonPhrase}');
      }
    }

    // Attempt to parse response as JSON, if fails return an empty success object
    try {
      final data = jsonDecode(response.body);
      return data;
    } catch (jsonError) {
      print('Success response is not valid JSON, returning generic success object: $jsonError');
      return {'success': true, 'message': 'Update successful'};
    }
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Remove User
Future<Map<String, dynamic>> removeUser(int userid) async {
  final creatorid = await Session.getUserId();
  final username = 'user_${creatorid ?? 0}'; // TODO: Get actual username from session
  final creatorUsername = username;
  
  try {
    final response = await http.delete(
      Uri.parse('$API_URL/users/removeUser/$userid?creatorid=$creatorid&creatorUsername=$creatorUsername'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete user');
    }

    return jsonDecode(response.body);
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Suspend User
Future<Map<String, dynamic>> suspendUser(int userid) async {
  final creatorid = await Session.getUserId();
  final username = 'user_${creatorid ?? 0}'; // TODO: Get actual username from session
  final creatorUsername = username;
  
  try {
    final response = await http.put(
      Uri.parse('$API_URL/users/suspendUser/$userid?creatorid=$creatorid&creatorUsername=$creatorUsername'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to suspend user');
    }

    return jsonDecode(response.body);
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Activate User
Future<Map<String, dynamic>> activateUser(int userid) async {
  final creatorid = await Session.getUserId();
  final username = 'user_${creatorid ?? 0}'; // TODO: Get actual username from session
  final creatorUsername = username;
  
  try {
    final response = await http.put(
      Uri.parse('$API_URL/users/activateUser/$userid?creatorid=$creatorid&creatorUsername=$creatorUsername'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to activate user');
    }

    return jsonDecode(response.body);
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Nodemailer For Contact Us
Future<Map<String, dynamic>> sendContactEmail(Map<String, dynamic> emailData) async {
  try {
    final response = await http.post(
      Uri.parse('$API_URL/contact_us'),
      headers: await _authHeaders(),
      body: jsonEncode(emailData),
    );

    return jsonDecode(response.body);
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Booking Request Notification
Future<Map<String, dynamic>> requestBooking(int reservationid) async {
  final creatorid = await Session.getUserId();
  final username = await Session.getUsername();
  final creatorUsername = username ?? 'user_${creatorid ?? 0}';
  
  try {
    print('API: Sending booking request notification for reservation ID: $reservationid');
    print('API: Creator ID: $creatorid, Creator Username: $creatorUsername');
    
    final url = '$API_URL/requestBooking/$reservationid?creatorid=$creatorid&creatorUsername=${Uri.encodeComponent(creatorUsername)}';
    print('API: Request URL: $url');
    
    final response = await http.post(
      Uri.parse(url),
      headers: await _authHeaders(),
    );

    print('API: Booking request response status: ${response.statusCode}');
    print('API: Booking request response body: ${response.body}');

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to send booking request notification');
    }

    final result = jsonDecode(response.body);
    print('API: Booking request notification sent successfully: $result');
    return result;
  } catch (error) {
    print('API error sending booking request: $error');
    rethrow;
  }
}

// Booking Accepted Notification
Future<Map<String, dynamic>> acceptBooking(int reservationid) async {
  final creatorid = await Session.getUserId();
  final username = 'user_${creatorid ?? 0}'; // TODO: Get actual username from session
  final creatorUsername = username;
  
  try {
    final response = await http.post(
      Uri.parse('$API_URL/accept_booking/$reservationid?creatorid=$creatorid&creatorUsername=$creatorUsername'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to send booking accepted notification');
    }

    return jsonDecode(response.body);
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Suggest New Room
Future<Map<String, dynamic>> suggestNewRoom(int propertyid, int reservationid) async {
  final creatorid = await Session.getUserId();
  final username = await Session.getUsername();
  final creatorUsername = username ?? 'user_${creatorid ?? 0}';
  
  try {
    final response = await http.post(
      Uri.parse('$API_URL/suggestNewRoom/$propertyid/$reservationid?creatorid=$creatorid&creatorUsername=${Uri.encodeComponent(creatorUsername)}'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to send new room suggested notification');
    }

    return jsonDecode(response.body);
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Notify Admin for Room Suggestion (when moderator can't suggest alternative)
Future<Map<String, dynamic>> notifyAdminForRoomSuggestion(int reservationid, String reason) async {
  final creatorid = await Session.getUserId();
  final username = await Session.getUsername();
  final creatorUsername = username ?? 'user_${creatorid ?? 0}';
  
  try {
    final response = await http.post(
      Uri.parse('$API_URL/notifyAdminForRoomSuggestion/$reservationid?creatorid=$creatorid&creatorUsername=${Uri.encodeComponent(creatorUsername)}&reason=${Uri.encodeComponent(reason)}'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to notify admin for room suggestion');
    }

    return jsonDecode(response.body);
  } catch (error) {
    print('API error notifying admin for room suggestion: $error');
    rethrow;
  }
}

// Property Listing Request Notification
Future<Map<String, dynamic>> propertyListingRequest(int propertyid) async {
  final creatorid = await Session.getUserId();
  final username = 'user_${creatorid ?? 0}'; // TODO: Get actual username from session
  final creatorUsername = username;
  
  try {
    final response = await http.post(
      Uri.parse('$API_URL/propertyListingRequest/$propertyid?creatorid=$creatorid&creatorUsername=$creatorUsername'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to send property listing request notification');
    }

    return jsonDecode(response.body);
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Property Listing Request Accepted Notification
Future<Map<String, dynamic>> propertyListingAccept(int propertyid) async {
  final creatorid = await Session.getUserId();
  final username = 'user_${creatorid ?? 0}'; // TODO: Get actual username from session
  final creatorUsername = username;
  
  try {
    final response = await http.post(
      Uri.parse('$API_URL/propertyListingAccept/$propertyid?creatorid=$creatorid&creatorUsername=$creatorUsername'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to send property listing request accepted notification');
    }

    return jsonDecode(response.body);
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Property Listing Request Rejected Notification
Future<Map<String, dynamic>> propertyListingReject(int propertyid) async {
  final creatorid = await Session.getUserId();
  final username = 'user_${creatorid ?? 0}'; // TODO: Get actual username from session
  final creatorUsername = username;
  
  try {
    final response = await http.post(
      Uri.parse('$API_URL/propertyListingReject/$propertyid?creatorid=$creatorid&creatorUsername=$creatorUsername'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to send property listing request rejected notification');
    }

    return jsonDecode(response.body);
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Send Suggest Notification 
Future<Map<String, dynamic>> sendSuggestNotification(int reservationid, List<int> selectedOperators) async {
  final creatorid = await Session.getUserId();
  final username = 'user_${creatorid ?? 0}'; // TODO: Get actual username from session
  final creatorUsername = username;
  
  try {
    final response = await http.post(
      Uri.parse('$API_URL/sendSuggestNotification/$reservationid?creatorid=$creatorid&creatorUsername=$creatorUsername'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'userids': selectedOperators,
      }),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to send suggest notification');
    }

    return jsonDecode(response.body);
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Send Picked Up Notification To Original Reservation Owner
Future<Map<String, dynamic>> sendPickedUpNotification(int reservationid) async {
  final creatorid = await Session.getUserId();
  final username = 'user_${creatorid ?? 0}'; // TODO: Get actual username from session
  final creatorUsername = username;
  
  try {
    final response = await http.post(
      Uri.parse('$API_URL/sendPickedUpNotification/$reservationid?creatorid=$creatorid&creatorUsername=$creatorUsername'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to send picked up notification');
    }

    return jsonDecode(response.body);
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Send Suggested Room Rejected Message To Operators
Future<Map<String, dynamic>> rejectSuggestedRoom(int propertyid) async {
  final creatorid = await Session.getUserId();
  final username = 'user_${creatorid ?? 0}'; // TODO: Get actual username from session
  final creatorUsername = username;
  
  try {
    final response = await http.post(
      Uri.parse('$API_URL/reject_suggested_room/$propertyid?creatorid=$creatorid&creatorUsername=$creatorUsername'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to send suggested room rejected notification');
    }

    return jsonDecode(response.body);
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Store Reservation Data
Future<Map<String, dynamic>> createReservation(Map<String, dynamic> reservationData) async {
  final userid = await Session.getUserId();
  final creatorid = await Session.getUserId();
  final username = await Session.getUsername();
  final creatorUsername = username ?? 'user_${creatorid ?? 0}';
  
  try {
    if (userid == null) {
      throw Exception('User not logged in. Please log in to create a reservation.');
    }

    print('API: Creating reservation for userid: $userid, username: $creatorUsername');
    print('API: Reservation data: $reservationData');

    final reservationWithuserid = {...reservationData, 'userid': userid};
    
    final response = await http.post(
      Uri.parse('$API_URL/reservation/$userid?creatorid=$creatorid&creatorUsername=${Uri.encodeComponent(creatorUsername)}'),
      headers: await _authHeaders(),
      body: jsonEncode(reservationWithuserid),
    );

    print('API: Reservation response status: ${response.statusCode}');
    print('API: Reservation response body: ${response.body}');

    // Accept both 200 (OK) and 201 (Created) as success status codes
    if (response.statusCode != 200 && response.statusCode != 201) {
      try {
        final errorData = jsonDecode(response.body);
        // Try to get detailed error message, fallback to generic message
        final errorMessage = errorData['details'] ?? 
                            errorData['error'] ?? 
                            errorData['message'] ?? 
                            'Failed to create reservation';
        print('API: Server error: ${response.statusCode} ${response.reasonPhrase}');
        print('API: Error data: $errorData');
        throw Exception(errorMessage);
      } catch (e) {
        if (e is Exception) {
          rethrow;
        }
        // If JSON parsing fails, use the raw response
        print('API: Failed to parse error response, using raw body');
        throw Exception('Failed to create reservation: ${response.statusCode} ${response.reasonPhrase}');
      }
    }

    final result = jsonDecode(response.body);
    if (result == null || result['reservationid'] == null) {
      throw Exception('No valid reservation ID received from server');
    }

    print('API: Reservation created successfully with ID: ${result['reservationid']}');
    return result;
  } catch (error) {
    print('API error creating reservation: $error');
    rethrow;
  }
}

Future<Map<String, dynamic>> checkDateOverlap({
  required int propertyId,
  required String checkIn,
  required String checkOut,
}) async {
  final creatorid = (await Session.getUserId())?.toString() ?? '';
  final creatorUsername = (await Session.getUsername())?.toString() ?? '';

  try {
    final response = await http.post(
      Uri.parse(
        '$API_URL/check-date-overlap/$propertyId'
        '?creatorid=${Uri.encodeComponent(creatorid)}'
        '&creatorUsername=${Uri.encodeComponent(creatorUsername)}',
      ),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'propertyid': propertyId,
        'checkIn': checkIn,
        'checkOut': checkOut,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to check date overlap');
    }

    final data = Map<String, dynamic>.from(jsonDecode(response.body));

    final overlap = data['overlap'] == true || data['isOverlap'] == true;

    return {
      ...data,
      'overlap': overlap,
      'isOverlap': overlap,
      'isBlackout': data['isBlackout'] == true,
    };
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Fetch all Reservations (dashboard views; can return many users' reservations depending on role)
Future<List<dynamic>> fetchReservation() async {
  final username = await Session.getUsername();
  
  try {
    if (username == null || username.isEmpty) {
      print('API: Username not found in session, returning empty reservations');
      return [];
    }

    print('API: Fetching reservations for username: $username');
    final response = await http.get(
      Uri.parse('$API_URL/reservationTable?username=${Uri.encodeComponent(username)}'),
      headers: await _authHeaders(),
    );

    print('API: Reservations response status: ${response.statusCode}');

    // 404 means no reservations found - that's okay
    if (response.statusCode == 404) {
      print('API: No reservations found (404), returning empty list');
      return [];
    }

    if (response.statusCode != 200) {
      print('API: Unexpected status ${response.statusCode}, returning empty list');
      return [];
    }

    final data = jsonDecode(response.body);

    // Try different possible keys
    if (data['reservations'] != null && data['reservations'] is List) {
      print('API: Found ${(data['reservations'] as List).length} reservations');
      return data['reservations'];
    } else if (data is List) {
      print('API: Response is direct list with ${data.length} reservations');
      return data;
    }

    return [];
  } catch (error) {
    print('API error fetching reservations: $error');
    return [];
  }
}

// Fetch Reservations for the currently logged-in customer only (Cart / Bookings)
Future<List<dynamic>> fetchCustomerReservations() async {
  final userid = await Session.getUserId();

  try {
    if (userid == null) {
      print('API: fetchCustomerReservations -> userid is null, returning empty list');
      return [];
    }

    print('API: Fetching customer reservations for userid: $userid');
    final response = await http.get(
      Uri.parse('$API_URL/cart?userid=$userid'),
      headers: await _authHeaders(),
    );

    print('API: Customer reservations response status: ${response.statusCode}');

    if (response.statusCode == 404) {
      print('API: No customer reservations found (404), returning empty list');
      return [];
    }

    if (response.statusCode != 200) {
      print('API: Unexpected status ${response.statusCode} from /cart, returning empty list');
      return [];
    }

    final dynamic data = jsonDecode(response.body);
    if (data is Map<String, dynamic>) {
      if (data['reservations'] != null && data['reservations'] is List) {
        print('API: Customer reservations count: ${(data['reservations'] as List).length}');
        return data['reservations'] as List<dynamic>;
      }
    } else if (data is List) {
      print('API: /cart responded with direct list, count: ${data.length}');
      return data;
    }

    return [];
  } catch (error) {
    print('API error fetching customer reservations: $error');
    return [];
  }
}

// Fetch Reservations for Admin/Moderator (based on hierarchy)
Future<List<dynamic>> fetchReservationsForAdminModerator() async {
  final username = await Session.getUsername();
  
  try {
    if (username == null || username.isEmpty) {
      print('API: Username not found in session, returning empty reservations');
      return [];
    }

    print('API: Fetching reservations for operator username: $username');
    
    final url = '$API_URL/reservationTable?username=${Uri.encodeComponent(username)}';
    print('API: Request URL: $url');
    
    final response = await http.get(
      Uri.parse(url),
      headers: await _authHeaders(),
    );

    print('API: Reservations response status: ${response.statusCode}');
    if (response.statusCode == 200) {
      final bodyPreview = response.body.length > 500
          ? response.body.substring(0, 500)
          : response.body;
      print('API: Reservations response body preview: $bodyPreview');
    }

    // 404 means no reservations found - that's okay
    if (response.statusCode == 404) {
      print('API: No reservations found (404), returning empty list');
      return [];
    }

    if (response.statusCode != 200) {
      print('API: Unexpected status ${response.statusCode}, returning empty list');
      return [];
    }

    final data = jsonDecode(response.body);
    
    // Try different possible keys
    if (data['reservations'] != null && data['reservations'] is List) {
      print('API: Found ${(data['reservations'] as List).length} reservations');
      return data['reservations'];
    } else if (data is List) {
      print('API: Response is direct list with ${data.length} reservations');
      return data;
    }
    
    return [];
  } catch (error) {
    print('API error fetching reservations for admin/moderator: $error');
    return [];
  }
}

// Update reservation status
Future<Map<String, dynamic>> updateReservationStatus(
  int reservationid,
  String status, {
  String creatorid = '',
  String creatorUsername = '',
}) async {
  final userid =
      await Session.getUserId();

  final storedUsername =
      await Session.getUsername();

  final isExpiredStatus =
      status.trim().toLowerCase() == 'expired';

  final finalCreatorId = isExpiredStatus
      ? ''
      : (creatorid.isNotEmpty ? creatorid : (userid?.toString() ?? ''));

  final finalCreatorUsername = isExpiredStatus
      ? ''
      : (creatorUsername.isNotEmpty ? creatorUsername : (storedUsername ?? ''));

  final queryParams = <String, String>{
    'userid': userid?.toString() ?? '',
  };

  if (finalCreatorId.isNotEmpty) {
    queryParams['creatorid'] = finalCreatorId;
  }

  if (finalCreatorUsername.isNotEmpty) {
    queryParams['creatorUsername'] = finalCreatorUsername;
  }

  final uri = Uri.parse(
    '$API_URL/updateReservationStatus/$reservationid',
  ).replace(
    queryParameters: queryParams,
  );

  try {
    final response = await http.patch(
      uri,
      headers: {
        ...await _authHeaders(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'reservationStatus': status,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to update reservation status (${response.statusCode}): ${response.body}',
      );
    }

    return jsonDecode(response.body);
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// CALCULATE BOOKING PRICE
Future<Map<String, dynamic>> calculateBookingPrice(
  String checkInDate,
  String checkOutDate,
  double basePrice,
  int propertyid,
) async {
  final response = await http.post(
    Uri.parse('$API_URL/calculate-price'),
    headers: {
      ...await _authHeaders(),
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'checkInDate': checkInDate,
      'checkOutDate': checkOutDate,
      'basePrice': basePrice,
      'propertyid': propertyid,
    }),
  );

  final data = jsonDecode(response.body);

  if (response.statusCode != 200) {
    throw Exception(data['message'] ?? 'Failed to calculate dynamic price');
  }

  return data;
}

// Cart
Future<List<dynamic>> fetchCart() async {
  final userid = await Session.getUserId();
  
  try {
    if (userid == null) {
      print('API: User ID not found in session, returning empty cart');
      return [];
    }

    print('API: Fetching cart for userid: $userid');
    final response = await http.get(
      Uri.parse('$API_URL/cart?userid=$userid'),
      headers: await _authHeaders(),
    );

    print('API: Cart response status: ${response.statusCode}');

    // 404 means no cart items found - that's okay
    if (response.statusCode == 404) {
      print('API: No cart items found (404), returning empty list');
      return [];
    }

    if (response.statusCode != 200) {
      print('API: Unexpected status ${response.statusCode}, returning empty list');
      return [];
    }

    final data = jsonDecode(response.body);
    
    // Try different possible keys
    if (data['reservations'] != null && data['reservations'] is List) {
      print('API: Found ${(data['reservations'] as List).length} cart items');
      return data['reservations'];
    } else if (data is List) {
      print('API: Response is direct list with ${data.length} cart items');
      return data;
    }
    
    return [];
  } catch (error) {
    print('API error fetching cart: $error');
    return [];
  }
}

// Remove Reservation
Future<Map<String, dynamic>> removeReservation(int reservationid) async {
  final creatorid = await Session.getUserId();
  final username = 'user_${creatorid ?? 0}'; // TODO: Get actual username from session
  final creatorUsername = username;
  
  try {
    final response = await http.delete(
      Uri.parse('$API_URL/removeReservation/$reservationid?creatorid=$creatorid&creatorUsername=$creatorUsername'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete reservation');
    }

    return jsonDecode(response.body);
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Book & Pay Log
Future<Map<String, dynamic>> fetchBookLog(int userid) async {
  try {
    final response = await http.get(
      Uri.parse('$API_URL/users/booklog?userid=$userid'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch book logs');
    }

    final data = jsonDecode(response.body);

    return data; 
  } catch (error) {
    print('API error fetching book logs: $error');
    rethrow;
  }
}

// Fetch Book and Pay Logs (for admin/moderator/owner)
Future<List<dynamic>> fetchBookAndPayLogs(int userid, [String usergroup = '']) async {
  final endpoints = [
    '/book-and-pay-log',
    '/users/book-and-pay-log',
    '/booklog',
    '/users/booklog',
    '/book_and_pay_log',
  ];

  for (final endpoint in endpoints) {
    try {
      final params = 'userid=${Uri.encodeComponent(userid.toString())}${usergroup.isNotEmpty ? '&usergroup=${Uri.encodeComponent(usergroup)}' : ''}';
      print('API: Trying endpoint: $endpoint?$params');
      final response = await http.get(
        Uri.parse('$API_URL$endpoint?$params'),
        headers: await _authHeaders(),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out');
        },
      );

      print('API: Response status: ${response.statusCode}');
      print('API: Response content-type: ${response.headers['content-type']}');

      final contentType = response.headers['content-type'] ?? '';
      final bodyStart = response.body.trim();
      if (contentType.contains('text/html') || bodyStart.startsWith('<!DOCTYPE') || bodyStart.startsWith('<html')) {
        print('API: Received HTML response (likely 404) from $endpoint, trying next endpoint...');
        continue;
      }

      if (response.statusCode != 200) {
        try {
          final errorData = jsonDecode(response.body);
          print('API: Error response from $endpoint: ${errorData['message'] ?? 'Unknown error'}');
        } catch (e) {
          print('API: Non-200 status (${response.statusCode}) with non-JSON response from $endpoint, trying next endpoint...');
        }
        continue;
      }

      try {
        final responseBody = response.body;
        print('API: Response body length: ${responseBody.length}');
        print('API: Response body preview (first 500 chars): ${responseBody.length > 500 ? responseBody.substring(0, 500) : responseBody}');

        final data = jsonDecode(responseBody);
        print('API: Successfully parsed JSON response from $endpoint');
        print('API: Response type: ${data.runtimeType}');

        if (data is List) {
          print('API: Response is direct list with ${data.length} items');
          try {
            if (data.isNotEmpty) {
              print('API: First item type: ${data[0].runtimeType}');
              final firstItemStr = data[0].toString();
              print('API: First item preview: ${firstItemStr.length > 100 ? firstItemStr.substring(0, 100) : firstItemStr}');
            }
          } catch (e) {
            print('API: Error accessing first item: $e');
          }
          try {
            return List<dynamic>.from(data);
          } catch (e) {
            print('API: Error converting to List: $e');
            if (data is List) return data;
            rethrow;
          }
        } else if (data is Map) {
          print('API: Response is a Map with keys: ${data.keys.toList()}');
          if (data.containsKey('bookAndPayLogs') && data['bookAndPayLogs'] is List) {
            print('API: Found bookAndPayLogs with ${(data['bookAndPayLogs'] as List).length} items');
            return List<dynamic>.from(data['bookAndPayLogs'] as List);
          } else if (data.containsKey('bookLogs') && data['bookLogs'] is List) {
            return List<dynamic>.from(data['bookLogs'] as List);
          } else if (data.containsKey('logs') && data['logs'] is List) {
            print('API: Found logs with ${(data['logs'] as List).length} items');
            return List<dynamic>.from(data['logs'] as List);
          }
        }
        print('API: Response format not recognized. Type: ${data.runtimeType}, returning empty list');
        return [];
      } catch (e, stackTrace) {
        print('API: Failed to parse JSON from $endpoint: $e');
        print('API: Stack trace: $stackTrace');
        print('API: Response body preview (first 500 chars): ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');
        continue;
      }
    } catch (error) {
      print('API: Error with endpoint $endpoint: $error');
      continue;
    }
  }

  throw Exception(
    'Failed to fetch book and pay logs: All endpoints returned errors.\n'
    'Tried endpoints: ${endpoints.join(", ")}\n'
    'Please ensure the backend endpoint is implemented.\n'
    'Expected endpoint format: /book-and-pay-log?userid=$userid or /users/book-and-pay-log?userid=$userid'
  );
}


// Fetch Ledger Records
Future<Map<String, dynamic>> fetchLedger(int userid, {
  int page = 1,
  int limit = 10,
  String search = '',
  String status = '',
  String selectedDate = '',
  String sortOrder = 'reservation_latest',
}) async {
  try {
    final uri = Uri.parse('$API_URL/ledger').replace(queryParameters: {
      'userid': userid.toString(),
      'page': page.toString(),
      'limit': limit.toString(),
      'search': search,
      'status': status,
      'selectedDate': selectedDate,
      'sortOrder': sortOrder,
    });
    final response = await http.get(uri, headers: await _authHeaders());
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch ledger (${response.statusCode})');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  } catch (error) {
    print('API error fetching ledger: $error');
    rethrow;
  }
}

// Fetch Ledger Summary
Future<Map<String, dynamic>> fetchLedgerSummary(int userid, {String selectedDate = ''}) async {
  try {
    final uri = Uri.parse('$API_URL/ledger/summary').replace(queryParameters: {
      'userid': userid.toString(),
      'selectedDate': selectedDate,
    });
    final response = await http.get(uri, headers: await _authHeaders());
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch ledger summary (${response.statusCode})');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['summary'] as Map<String, dynamic>? ?? {};
  } catch (error) {
    print('API error fetching ledger summary: $error');
    rethrow;
  }
}

// Fetch Finance Ledger Card (summary + monthly breakdown)
Future<Map<String, dynamic>> fetchFinanceLedgerCard(int userid) async {
  try {
    final uri = Uri.parse('$API_URL/finance/ledger-card').replace(queryParameters: {
      'userid': userid.toString(),
    });
    final response = await http.get(uri, headers: await _authHeaders());
    if (response.statusCode != 200) {
      print('API: Finance ledger-card returned status ${response.statusCode}');
      return {};
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  } catch (error) {
    print('API error fetching finance ledger card: $error');
    return {};
  }
}

// Fetch Finance Review Chart (summary + monthly breakdown)
Future<Map<String, dynamic>> fetchFinanceReviewChart(int userid) async {
  try {
    final uri = Uri.parse('$API_URL/finance/review-chart').replace(queryParameters: {
      'userid': userid.toString(),
    });
    final response = await http.get(uri, headers: await _authHeaders());
    if (response.statusCode != 200) {
      print('API: Finance review-chart returned status ${response.statusCode}');
      return {};
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  } catch (error) {
    print('API error fetching finance review chart: $error');
    return {};
  }
}

// Fetch Finance Chart Data
Future<List<dynamic>> fetchFinanceChart(int userid, {
  String chartType = 'booking_revenue',
  String year = '',
  String month = '',
}) async {
  try {
    final params = <String, String>{
      'userid': userid.toString(),
      'chartType': chartType,
    };
    if (year.isNotEmpty) params['year'] = year;
    if (month.isNotEmpty) params['month'] = month;

    final uri = Uri.parse('$API_URL/users/finance/chart').replace(queryParameters: params);
    final response = await http.get(uri, headers: await _authHeaders());
    if (response.statusCode != 200) return [];
    final data = jsonDecode(response.body);
    if (data is List) return data;
    if (data is Map) {
      if (data['data'] is List) return data['data'] as List;
      if (data['chart'] is List) return data['chart'] as List;
    }
    return [];
  } catch (error) {
    print('API error fetching finance chart: $error');
    return [];
  }
}

// Fetch Finance 
Future<Map<String, dynamic>> fetchFinance(int userid, {bool paidOnly = false}) async {
  try {
    print('API: Fetching finance for userid: $userid, paidOnly: $paidOnly');
    final uri = paidOnly
        ? Uri.parse('$API_URL/users/finance?userid=$userid&paidOnly=true')
        : Uri.parse('$API_URL/users/finance?userid=$userid');
    final response = await http.get(uri, headers: await _authHeaders());
    
    print('API: Finance response status: ${response.statusCode}');
    
    if (response.statusCode != 200) {
      print('API: Finance returned status ${response.statusCode}, returning empty');
      return {};
    }
    
    final data = jsonDecode(response.body);
    print('API: Finance data keys: ${data.keys.toList()}');
      return data; 
  } catch (error) {
    print('API error fetching finance: $error');
    return {};
  }
}

/// Fetch Average Revenue (pre-calculated on backend)
/// Backend endpoint is expected to compute the average revenue for the user
/// based on their role and return a JSON like:
/// `{ "averageRevenue": 432.75 }`
Future<double> fetchAverageRevenue(int userid) async {
  try {
    print('API: Fetching average revenue for userid: $userid');
    final uri = Uri.parse('$API_URL/users/average_revenue?userid=$userid');
    final response = await http.get(uri, headers: await _authHeaders());

    print('API: Average revenue response status: ${response.statusCode}');
    if (response.statusCode != 200) {
      print('API: Average revenue returned status ${response.statusCode}, defaulting to 0');
      return 0.0;
    }

    final data = jsonDecode(response.body);
    print('API: Average revenue response body: $data');

    final dynamic value = data['averageRevenue'] ??
        data['average_revenue'] ??
        data['avgRevenue'] ??
        data['avg_revenue'];

    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  } catch (error) {
    print('API error fetching average revenue: $error');
    return 0.0;
  }
}

// Fetch Occupancy Rate
Future<Map<String, dynamic>> fetchOccupancyRate(int userid, {bool paidOnly = false}) async {
  try {
    print('API: Fetching occupancy rate for userid: $userid, paidOnly: $paidOnly');
    final uri = paidOnly
        ? Uri.parse('$API_URL/users/occupancy_rate?userid=$userid&paidOnly=true')
        : Uri.parse('$API_URL/users/occupancy_rate?userid=$userid');
    final response = await http.get(uri, headers: await _authHeaders());
    
    print('API: Occupancy rate response status: ${response.statusCode}');
    
    if (response.statusCode != 200) {
      print('API: Occupancy rate returned status ${response.statusCode}, returning empty');
      return {};
    }
    
    final data = jsonDecode(response.body);
    print('API: Occupancy rate data keys: ${data.keys.toList()}');
      return data; 
  } catch (error) {
    print('API error fetching occupancy rate: $error');
    return {};
  }
}

// Fetch Reservation per Available Room
Future<Map<String, dynamic>> fetchRevPAR(int userid, {bool paidOnly = false}) async {
  try {
    print('API: Fetching RevPAR for userid: $userid, paidOnly: $paidOnly');
    final uri = paidOnly
        ? Uri.parse('$API_URL/users/RevPAR?userid=$userid&paidOnly=true')
        : Uri.parse('$API_URL/users/RevPAR?userid=$userid');
    final response = await http.get(uri, headers: await _authHeaders());
    
    print('API: RevPAR response status: ${response.statusCode}');
    
    if (response.statusCode != 200) {
      print('API: RevPAR returned status ${response.statusCode}, returning empty');
      return {};
    }
    
    final data = jsonDecode(response.body);
    print('API: RevPAR data keys: ${data.keys.toList()}');
      return data; 
  } catch (error) {
    print('API error fetching RevPAR: $error');
    return {};
  }
}

// Fetch Cancellation Rate
Future<Map<String, dynamic>> fetchCancellationRate(int userid) async {
  try {
    final response = await http.get(
      Uri.parse('$API_URL/users/cancellation_rate?userid=$userid'),
      headers: await _authHeaders(),
    );
    final data = jsonDecode(response.body);
      return data; 
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Fetch Customer Retention Rate
Future<Map<String, dynamic>> fetchCustomerRetentionRate(int userid) async {
  try {
    final response = await http.get(
      Uri.parse('$API_URL/users/customer_retention_rate?userid=$userid'),
      headers: await _authHeaders(),
    );
    final data = jsonDecode(response.body);
      return data; 
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Fetch Guest Satisfaction Score
Future<Map<String, dynamic>> fetchGuestSatisfactionScore(int userid, {bool paidOnly = false}) async {
  try {
    print('API: Fetching guest satisfaction score for userid: $userid, paidOnly: $paidOnly');
    final uri = paidOnly
        ? Uri.parse('$API_URL/users/guest_satisfaction_score?userid=$userid&paidOnly=true')
        : Uri.parse('$API_URL/users/guest_satisfaction_score?userid=$userid');
    final response = await http.get(uri, headers: await _authHeaders());
    
    print('API: Guest satisfaction response status: ${response.statusCode}');
    
    if (response.statusCode != 200) {
      print('API: Guest satisfaction returned status ${response.statusCode}, returning empty');
      return {};
    }
    
    final data = jsonDecode(response.body);
    print('API: Guest satisfaction data keys: ${data.keys.toList()}');
      return data; 
  } catch (error) {
    print('API error fetching guest satisfaction: $error');
    return {};
  }
}

// Fetch Average Length of Stay
Future<Map<String, dynamic>> fetchALOS(int userid) async {
  try {
    final response = await http.get(
      Uri.parse('$API_URL/users/alos?userid=$userid'),
      headers: await _authHeaders(),
    );
    final data = jsonDecode(response.body);
      return data; 
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Get Properties Of Administrator For "Suggest"
Future<Map<String, dynamic>> getOperatorProperties(int userid, int reservationid) async {
  try {
    final response = await http.get(
      Uri.parse('$API_URL/operatorProperties/$userid/$reservationid'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to get properties');
    }

    final data = jsonDecode(response.body);
    return data;
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Fetch normal user data
Future<Map<String, dynamic>> fetchUserData(int userid) async {
  try {
    final response = await http.get(
      Uri.parse('$API_URL/users/$userid'),
      headers: await _authHeaders(),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch user data');
    }
    
    return jsonDecode(response.body);
  } catch (error) {
    print('Error fetching user data: $error');
    rethrow;
  }
}

// Fetch google user data
Future<Map<String, dynamic>?> fetchGoogleUserData(String accessToken) async {
  try {
    final response = await http.get(
      Uri.parse('https://www.googleapis.com/oauth2/v1/userinfo?access_token=$accessToken'),
          headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
          },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch Google user data');
      }

    final profile = jsonDecode(response.body);
      return profile;
  } catch (error) {
    print("Error fetching Google user data: $error");
      return null;
  }
}

// Update user profile
Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> userData) async {
  final creatorid = await Session.getUserId();
  final username = 'user_${creatorid ?? 0}'; // TODO: Get actual username from session
  final creatorUsername = username;
    
    try {
        // Validate user ID
    if (userData['userid'] == null) {
      throw Exception('User ID is missing');
        }
      
    print('API: Updating profile for userid: ${userData['userid']}');
    print('API: Profile data: $userData');
    
    // Create a clean payload - only send fields that are actually provided
    final cleanData = <String, dynamic>{
      'userid': userData['userid'],
    };
    
    // Add all required fields from backend
    if (userData.containsKey('username')) cleanData['username'] = userData['username'];
    // Only send password if it's explicitly provided and not empty
    // This prevents accidentally overwriting password when updating other fields
    if (userData.containsKey('password') && userData['password'] != null && userData['password'].toString().isNotEmpty) {
      cleanData['password'] = userData['password'];
    }
    if (userData.containsKey('ufirstname')) cleanData['ufirstname'] = userData['ufirstname'];
    if (userData.containsKey('ulastname')) cleanData['ulastname'] = userData['ulastname'];
    if (userData.containsKey('udob')) cleanData['udob'] = userData['udob'];
    if (userData.containsKey('utitle')) cleanData['utitle'] = userData['utitle'];
    if (userData.containsKey('ugender')) cleanData['ugender'] = userData['ugender'];
    if (userData.containsKey('uemail')) cleanData['uemail'] = userData['uemail'];
    if (userData.containsKey('uphoneno')) cleanData['uphoneno'] = userData['uphoneno'];
    if (userData.containsKey('ucountry')) cleanData['ucountry'] = userData['ucountry'];
    if (userData.containsKey('uzipcode')) cleanData['uzipcode'] = userData['uzipcode'];
    
    // Add PayPal ID (backend expects 'paypalid', not 'paypal_email')
    if (userData.containsKey('paypalid') && userData['paypalid'] != null) {
      cleanData['paypalid'] = userData['paypalid'];
    } else if (userData.containsKey('paypal_email') && userData['paypal_email'] != null) {
      // Fallback: if frontend sends paypal_email, map it to paypalid
      cleanData['paypalid'] = userData['paypal_email'];
    }
    
    print('API: Clean profile data being sent: $cleanData');
    
    final response = await http.put(
      Uri.parse('$API_URL/users/updateProfile/${userData['userid']}?creatorid=$creatorid&creatorUsername=$creatorUsername'),
      headers: await _authHeaders(),
      body: jsonEncode(cleanData),
    );

    print('API: Update profile response status: ${response.statusCode}');
    print('API: Update profile response body: ${response.body}');

    if (response.statusCode != 200) {
      try {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? errorData['error'] ?? 'Failed to update user profile';
        print('API: Error details: $errorData');
        throw Exception('$errorMessage (${response.statusCode})');
      } catch (e) {
        if (e is Exception && e.toString().contains('500')) {
          throw Exception('Server error: The backend encountered an error. Please check the backend logs.');
        }
        throw Exception('Failed to update user profile: ${response.statusCode} ${response.reasonPhrase}');
      }
    }

    try {
      return jsonDecode(response.body);
    } catch (e) {
      // If response is not JSON, return success anyway
      print('API: Response is not JSON, assuming success');
      return {'success': true, 'message': 'Profile updated successfully'};
    }
    } catch (error) {
    print('API error updating profile: $error');
    rethrow;
  }
}

// Upload Avatar
Future<Map<String, dynamic>> uploadAvatar(int userid, String base64String) async {
  final creatorid = await Session.getUserId();
  final username = 'user_${creatorid ?? 0}'; // TODO: Get actual username from session
  final creatorUsername = username;

  try {
    if (userid == 0) {
      throw Exception('User ID is missing');
    }

    final response = await http.post(
      Uri.parse('$API_URL/users/uploadAvatar/$userid?creatorid=$creatorid&creatorUsername=$creatorUsername'),
      headers: await _authHeaders(),
      body: jsonEncode({'uimage': base64String}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to upload avatar');
      }
  
      return data; 
    } catch (error) {
    print('API error: $error');
    rethrow;
    }
}

// Forgot Password
Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
    final response = await http.post(
      Uri.parse('$API_URL/forgot-password'),
      headers: _publicHeaders(),
      body: jsonEncode({'email': email}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Reset password failed');
        }

        return data; 
    } catch (error) {
    print('Reset password request error: $error');
    rethrow;
  }
}

// Verify Password Reset Code
Future<Map<String, dynamic>> verifyPasswordResetCode(String email, String code) async {
  try {
    final response = await http.post(
      Uri.parse('$API_URL/verify-reset-code'),
      headers: _publicHeaders(),
      body: jsonEncode({'email': email, 'code': code}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Code verification failed');
    }

    return data;
  } catch (error) {
    print('Verify reset code error: $error');
    rethrow;
  }
}

// Reset Password
Future<Map<String, dynamic>> resetPassword(String email, String code, String newPassword) async {
  try {
    final response = await http.post(
      Uri.parse('$API_URL/reset-password'),
      headers: _publicHeaders(),
      body: jsonEncode({
        'email': email,
        'code': code,
        'newPassword': newPassword,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Password reset failed');
    }

    return data;
  } catch (error) {
    print('Reset password error: $error');
    rethrow;
  }
}

// Google Login
Future<Map<String, dynamic>> googleLogin(String token) async {
  try {
    final response = await http.post(
      Uri.parse('$API_URL/google-login'),
      headers: _publicHeaders(),
      body: jsonEncode({'token': token}),
    );

    print('API: Google login status: ${response.statusCode}');
    print('API: Google login body: ${response.body}');

    // Backend returns:
    // - 200 for existing users
    // - 201 for newly created users
    if (response.statusCode != 200 && response.statusCode != 201) {
      final errorData = jsonDecode(response.body);
      print('API: Google login error response: $errorData');
      throw Exception(errorData['message'] ?? 'Google Login Failed');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data['accessToken'] != null && data['refreshToken'] != null) {
      await Session.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
    }

    return data;
  } catch (error) {
    print('Error in Google Login: $error');
    rethrow;
  }
}

// Google Map
Future<Map<String, double>> getCoordinates(String location) async {
  final response = await http.get(
    Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(location)}&key=AIzaSyCe27HezKpItahXjMFcWXf3LwFcjI7pZFk'),
  );
  final data = jsonDecode(response.body);
  if (data['results'] != null && (data['results'] as List).isNotEmpty) {
    final location = data['results'][0]['geometry']['location'];
    final lat = location['lat'] as double;
    final lng = location['lng'] as double;
    return {'lat': lat, 'lng': lng};
  }
  throw Exception('Location not found');
}

// Assign Role
Future<Map<String, dynamic>> assignRole(int userid, String role) async {
  final creatorid = await Session.getUserId();
  final creatorUsername = await Session.getUsername();
  
  if (creatorid == null || creatorUsername == null) {
    throw Exception('User session not found. Please log in again.');
  }

  final res = await http.post(
    Uri.parse('$API_URL/users/assignRole/$userid/$role?creatorid=$creatorid&creatorUsername=$creatorUsername'),
    headers: await _authHeaders(),
  );

  final text = res.body;
  Map<String, dynamic> data;

  try {
    data = jsonDecode(text) as Map<String, dynamic>;
  } catch (e) {
    throw Exception('Server returned unexpected response:\n$text');
  }

  if (res.statusCode != 200) {
    throw Exception(data['message'] ?? jsonEncode(data));
  }

  return data;
}

// Fetch Audit Trails
Future<List<dynamic>> auditTrails(int userid) async {
  try {
    final response = await http.get(
      Uri.parse('$API_URL/auditTrails?userid=$userid'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to fetch audit trails');
    }

    final data = jsonDecode(response.body);
    return data['auditTrails'];
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Submit a review for a property
Future<Map<String, dynamic>> submitReview(
  Map<String, dynamic> reviewData,
  String username,
) async {
  try {
    final response = await http.post(
      Uri.parse('$API_URL/reviews?creatorUsername=${Uri.encodeComponent(username)}'),
      headers: await _authHeaders(),
      body: jsonEncode(reviewData),
    );

    print('Response status: ${response.statusCode}');

    if (response.statusCode != 200 && response.statusCode != 201) {
      final errorData = jsonDecode(response.body);
      print('Server error response: $errorData');
      throw Exception(errorData['message'] ?? 'Failed to submit review');
    }

    return jsonDecode(response.body);
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Fetch all reviews for a moderator/owner (by userid)
Future<List<dynamic>> fetchOwnerReviews(int userid) async {
  try {
    final response = await http.get(
      Uri.parse('$API_URL/owner-reviews/$userid'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) {
      print('API: owner-reviews returned ${response.statusCode}');
      return [];
    }
    final data = jsonDecode(response.body);
    if (data is List) return data;
    return [];
  } catch (error) {
    print('API error fetching owner reviews: $error');
    return [];
  }
}

// Reply to a review (PUT with owner_reply text, or null to delete reply)
Future<bool> replyToReview(int reviewId, String? reply) async {
  try {
    final response = await http.put(
      Uri.parse('$API_URL/reviews/$reviewId/reply'),
      headers: await _authHeaders(),
      body: jsonEncode({'owner_reply': reply}),
    );
    return response.statusCode == 200;
  } catch (error) {
    print('API error replying to review: $error');
    return false;
  }
}

// Fetch reviews for a specific property
Future<Map<String, dynamic>> fetchReviews(int propertyid) async {
  try {
    final response = await http.get(
      Uri.parse('$API_URL/reviews/$propertyid'),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch property reviews');
    }
    
    return jsonDecode(response.body);
  } catch (error) {
    print('Error fetching property reviews: $error');
    rethrow;
  }
}

// Delete a review
Future<Map<String, dynamic>> deleteReview(dynamic reviewId, String username) async {
  final response = await http.delete(
    Uri.parse('$API_URL/reviews/$reviewId'),
    headers: await _authHeaders(),
  );

  Map<String, dynamic> data = {};
  try {
    data = jsonDecode(response.body);
  } catch (_) {
    data = {};
  }

  if (response.statusCode != 200) {
    throw Exception(data['message'] ?? 'Failed to delete review');
  }

  return data;
}

// Fetch all clusters
Future<Map<String, dynamic>> fetchClusters() async {
  try {
    print('API: Fetching clusters... (timestamp: ${DateTime.now().millisecondsSinceEpoch})');
    final response = await http.get(
      Uri.parse('$API_URL/clusters?_t=${DateTime.now().millisecondsSinceEpoch}'),
      headers: {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      },
    );
    
    print('API: Clusters response status: ${response.statusCode}');
    
    if (response.statusCode != 200) {
      print('API: Clusters returned status ${response.statusCode}, returning empty');
      return {'clusters': []};
    }
    
    final data = jsonDecode(response.body);
    print('API: Clusters data keys: ${data is Map ? (data as Map).keys.toList() : "direct list"}');
    return data is Map ? data as Map<String, dynamic> : {'clusters': data};
  } catch (error) {
    print('Error fetching clusters: $error');
    return {'clusters': []};
  }
}

// Fetch unique cluster names from the database
Future<Map<String, dynamic>> fetchClusterNames() async {
  try {
    final response = await http.get(
      Uri.parse('$API_URL/clusters/names'),
    );
    return jsonDecode(response.body);
  } catch (error) {
    print('Error fetching cluster names: $error');
    rethrow;
  }
}

// Fetch Suggested Reservations
Future<Map<String, dynamic>> suggestedReservations(int userid) async {
  try {
    final response = await http.get(
      Uri.parse('$API_URL/suggestedReservations/$userid'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to fetch suggested reservations');
    }

    final data = jsonDecode(response.body);
    return data;
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Fetch Published Reservations
Future<Map<String, dynamic>> publishedReservations(int userid) async {
  try {
    final response = await http.get(
      Uri.parse('$API_URL/publishedReservations/$userid'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to fetch published reservations');
    }

    final data = jsonDecode(response.body);
    return data;
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Add a new cluster
Future<Map<String, dynamic>> addCluster(Map<String, dynamic> clusterData) async {
  try {
    final response = await http.post(
      Uri.parse('$API_URL/clusters'),
      headers: await _authHeaders(),
      body: jsonEncode(clusterData),
    );

    return jsonDecode(response.body);
  } catch (error) {
    print('Error adding cluster: $error');
    rethrow;
  }
}

// Update an existing cluster
Future<Map<String, dynamic>> updateCluster(int clusterID, Map<String, dynamic> clusterData) async {
  try {
    final response = await http.put(
      Uri.parse('$API_URL/clusters/$clusterID'),
      headers: await _authHeaders(),
      body: jsonEncode(clusterData),
    );

    return jsonDecode(response.body);
  } catch (error) {
    print('Error updating cluster: $error');
    rethrow;
  }
}

// Delete a cluster
Future<Map<String, dynamic>> deleteCluster(int clusterID) async {
  try {
    final response = await http.delete(
      Uri.parse('$API_URL/clusters/$clusterID'),
      headers: await _authHeaders(),
    );

    return jsonDecode(response.body);
  } catch (error) {
    print('Error deleting cluster: $error');
    rethrow;
  }
}

// Fetch Categories
Future<Map<String, dynamic>> fetchCategories() async {
  try {
    final response = await http.get(
      Uri.parse('$API_URL/categories'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch categories');
    }

    final data = jsonDecode(response.body);
    return data; 
  } catch (error) {
    print('Error fetching categories: $error');
    rethrow;
  }
}

// Fetch current commission rate
Future<double> fetchCommissionRate() async {
  try {
    final response = await http.get(
      Uri.parse('$API_URL/api/commission'),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to fetch commission');
    }

    final data = jsonDecode(response.body);
    return double.tryParse(data['commission_rate'].toString()) ?? 0.07;
  } catch (error) {
    print("Error fetching commission rate: $error");
    return 0.07; // Fallback to 7%
  }
}

// Update the commission rate
Future<dynamic> updateCommissionRate(double newRateDecimal, dynamic userid) async {
  try {
    final response = await http.post(
      Uri.parse('$API_URL/api/commission'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'newRate': newRateDecimal,
        'userid': userid,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['error'] ?? "Failed to update commission rate");
    }

    return jsonDecode(response.body);
  } catch (error) {
    print("Backend Error Details: $error");
    rethrow;
  }
}

// Payment Successful Notification
Future<Map<String, dynamic>> paymentSuccess(int reservationid) async {
  final creatorid = await Session.getUserId();
  final username = 'user_${creatorid ?? 0}'; 
  final creatorUsername = username;
  
  try {
    print('API: Sending payment success notification - reservationId: $reservationid');
    final response = await http.post(
      Uri.parse('$API_URL/payment_success/$reservationid?creatorid=$creatorid&creatorUsername=$creatorUsername'),
      headers: await _authHeaders(),
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        print('API: paymentSuccess timed out after 15 seconds');
        throw TimeoutException('Request timed out after 15 seconds');
      },
    );

    print('API: paymentSuccess response status: ${response.statusCode}');
    if (response.statusCode != 200) {
      print('API: paymentSuccess failed with status ${response.statusCode}: ${response.body}');
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to send payment successful notification');
    }

    return jsonDecode(response.body);
  } catch (error) {
    print('API error sending payment success notification: $error');
    rethrow;
  }
}

// Notification History Feature
// Fetch Notifications for User
// Fetch Notification
Future<List<dynamic>> fetchNotifications(int userid) async {
  try {
    final uri = Uri.parse('$API_URL/notifications').replace(
      queryParameters: {
        'userid': userid.toString(),
      },
    );

    print('API: Fetch notifications URL: $uri');

    final response = await http.get(
      uri,
      headers: await _authHeaders(),
    );

    print('API: Fetch notifications status: ${response.statusCode}');
    print('API: Fetch notifications body: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch notifications');
    }

    final data = jsonDecode(response.body);

    if (data is List) {
      return data;
    }

    if (data is Map && data['notifications'] is List) {
      return data['notifications'];
    }

    return [];
  } catch (error) {
    print('API error fetching notifications: $error');
    rethrow;
  }
}

Future<Map<String, dynamic>> syncBookingAlertNotifications(int userid) async {
  try {
    final response = await http.post(
      Uri.parse('$API_URL/notifications/sync-booking-alerts/$userid'),
      headers: await _authHeaders(),
    );

    print('API: Sync booking alerts status: ${response.statusCode}');
    print('API: Sync booking alerts body: ${response.body}');

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to sync booking alerts');
    }

    return data;
  } catch (error) {
    print('API error syncing booking alerts: $error');
    rethrow;
  }
}

// Create Notification
Future<Map<String, dynamic>> createNotification(Map<String, dynamic> data) async {
  try {
    final response = await http.post(
      Uri.parse('$API_URL/notifications'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create notification');
    }

    return jsonDecode(response.body);
  } catch (error) {
    print('API error: $error');
    rethrow;
  }
}

// Mark a Notification as Read
Future<Map<String, dynamic>> markNotificationAsRead(int notificationid) async {
  try {
    final response = await http.put(
      Uri.parse('$API_URL/notifications/$notificationid/read'),
      headers: await _authHeaders(),
    );

    print('API: Mark notification read status: ${response.statusCode}');
    print('API: Mark notification read body: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Failed to mark notification as read');
    }

    return jsonDecode(response.body);
  } catch (error) {
    print('API error marking notification as read: $error');
    rethrow;
  }
}

// Mark All Notification as Read
Future<Map<String, dynamic>> markAllNotificationsAsRead(int userid) async {
  try {
    final response = await http.put(
      Uri.parse('$API_URL/notifications/read-all/$userid'),
      headers: await _authHeaders(),
    );

    print('API: Mark all notifications read status: ${response.statusCode}');
    print('API: Mark all notifications read body: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Failed to mark all notifications as read');
    }

    return jsonDecode(response.body);
  } catch (error) {
    print('API error marking all notifications as read: $error');
    rethrow;
  }
}

// Delete Notification
Future<bool> deleteNotification(int notificationId) async {
  final userid = await Session.getUserId();
  
  try {
    if (userid == null) {
      throw Exception('User ID not found');
    }

    final response = await http.delete(
      Uri.parse('$API_URL/notifications/$notificationId?userid=$userid'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to delete notification');
    }

    return true;
  } catch (error) {
    print('API error deleting notification: $error');
    return false;
  }
}

// Dynamic Pricing Settings
Future<dynamic> fetchPricingSettings() async {
  final response = await http.get(Uri.parse('$API_URL/pricing-settings'));

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('Failed to fetch pricing settings');
  }

  return jsonDecode(response.body);
}

Future<dynamic> savePricingSettings(Map<String, dynamic> settings) async {
  final response = await http.post(
    Uri.parse('$API_URL/pricing-settings'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(settings),
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('Failed to save pricing settings');
  }

  return jsonDecode(response.body);
}

// Festive and holiday pricing
// Fetch official Sarawak/Malaysia holidays from backend scraper
Future<List<dynamic>> fetchHolidaysFromApi(int year) async {
  final response = await http.get(
    Uri.parse('$API_URL/fetch-holidays/$year'),
    headers: await _authHeaders(),
  );

  final data = jsonDecode(response.body);

  if (response.statusCode != 200) {
    throw Exception(data['message'] ?? 'Failed to fetch official holidays');
  }

  return data['holidays'] ?? [];
}

// Fetch saved Official Holidays from PostgreSQL database
Future<dynamic> fetchHolidaysFromDb() async {
  final response = await http.get(
    Uri.parse('$API_URL/manage-holidays'),
    headers: await _authHeaders(),
  );

  final data = jsonDecode(response.body);

  if (response.statusCode != 200) {
    throw Exception(data['message'] ?? 'Failed to fetch saved holidays from database');
  }

  return data;
}

// Save Official Holidays & Rates to PostgreSQL database
Future<Map<String, dynamic>> saveHolidaysToDb(List<dynamic> holidays) async {
  final response = await http.post(
    Uri.parse('$API_URL/manage-holidays'),
    headers: {
      ...await _authHeaders(),
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'holidays': holidays,
    }),
  );

  final data = jsonDecode(response.body);

  if (response.statusCode != 200 && response.statusCode != 201) {
    throw Exception(data['message'] ?? 'Failed to save holidays to database');
  }

  return data;
}

// Fetch saved Custom Festive Periods from PostgreSQL database
Future<dynamic> fetchFestiveFromDb() async {
  final response = await http.get(
    Uri.parse('$API_URL/manage-festive'),
    headers: await _authHeaders(),
  );

  final data = jsonDecode(response.body);

  if (response.statusCode != 200) {
    throw Exception(data['message'] ?? 'Failed to fetch festive periods from database');
  }

  return data;
}

// Save Custom Festive Periods & Rates to PostgreSQL database
Future<Map<String, dynamic>> saveFestiveToDb(List<dynamic> festivePeriods) async {
  final response = await http.post(
    Uri.parse('$API_URL/manage-festive'),
    headers: {
      ...await _authHeaders(),
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'festivePeriods': festivePeriods,
    }),
  );

  final data = jsonDecode(response.body);

  if (response.statusCode != 200 && response.statusCode != 201) {
    throw Exception(data['message'] ?? 'Failed to save festive periods to database');
  }

  return data;
}

// Soldout Dates
Future<List<String>> fetchPropertySoldOutDates({
  required int propertyId,
  int days = 90,
}) async {
  final uri = Uri.parse('$API_URL/property-sold-out-dates').replace(
    queryParameters: {
      'propertyid': propertyId.toString(),
      'days': days.toString(),
    },
  );

  final response = await http.get(uri);
  final data = jsonDecode(response.body);

  if (response.statusCode != 200) {
    throw Exception(data['message'] ?? 'Failed to fetch sold-out dates');
  }

  final list = data['soldOutDates'] ?? [];
  return List<String>.from(list.map((e) => '$e'));
}

// Blackout Dates
Future<dynamic> fetchBlackoutDates() async {
  final userid = await Session.getUserId();
  final userGroup = await Session.getUserGroup();

  final response = await http.get(
    Uri.parse(
      '$API_URL/blackouts'
      '?userid=${Uri.encodeComponent(userid?.toString() ?? '')}'
      '&usergroup=${Uri.encodeComponent(userGroup?.toString() ?? '')}',
    ),
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('Failed to fetch blackout dates');
  }

  return jsonDecode(response.body);
}

// Fetch Blackout Dates (for moderator — filtered to own properties server-side)
Future<List<dynamic>> fetchBlackouts(int userid, String usergroup) async {
  try {
    final url = '$API_URL/blackouts?userid=$userid&usergroup=${Uri.encodeComponent(usergroup)}';
    print('API: Fetching blackouts from $url');
    final response = await http.get(Uri.parse(url), headers: await _authHeaders());
    print('API: fetchBlackouts status ${response.statusCode}');
    if (response.statusCode == 404) return [];
    if (response.statusCode != 200) {
      print('API: fetchBlackouts unexpected status ${response.statusCode}');
      return [];
    }
    final data = jsonDecode(response.body);
    if (data is List) return data;
    if (data['blackouts'] is List) return data['blackouts'];
    if (data['data'] is List) return data['data'];
    return [];
  } catch (error) {
    print('API error fetching blackouts: $error');
    return [];
  }
}

Future<dynamic> createBlackout(Map<String, dynamic> blackoutData) async {
  final userid = await Session.getUserId() ?? '';
  final username = await Session.getUsername() ?? '';
  final userGroup = await Session.getUserGroup() ?? '';

  final response = await http.post(
    Uri.parse('$API_URL/blackouts'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      ...blackoutData,
      'property_name': blackoutData['propertyName'] ?? blackoutData['property_name'],
      'created_by_userid': userid,
      'created_by_username': username,
      'created_by_role': userGroup.toLowerCase().contains('admin') ? 'admin' : 'moderator',
    }),
  );

  final data = jsonDecode(response.body);

  if (response.statusCode == 409) {
    return {
      'isConflict': true,
      'conflicts': data['conflicts'] ?? [],
      'message': data['message'] ?? 'Conflict detected',
    };
  }

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(data['message'] ?? 'Failed to create blackout');
  }

  return data;
}

Future<dynamic> overrideBlackout(dynamic blackoutId, String overrideReason) async {
  final userid = await Session.getUserId() ?? '';
  final username = await Session.getUsername() ?? '';
  final userGroup = await Session.getUserGroup() ?? '';

  final response = await http.patch(
    Uri.parse('$API_URL/blackouts/$blackoutId/override'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'overrideReason': overrideReason,
      'override_by_userid': userid,
      'override_by_username': username,
      'override_by_role': userGroup,
    }),
  );

  final data = jsonDecode(response.body);

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(data['message'] ?? 'Failed to override blackout');
  }

  return data;
}

Future<dynamic> deleteBlackout(dynamic blackoutId) async {
  final userid = (await Session.getUserId())?.toString() ?? '';
  final userGroup = (await Session.getUserGroup())?.toString() ?? '';

  final uri = Uri.parse('$API_URL/blackouts/$blackoutId').replace(
    queryParameters: {
      'userid': userid,
      'usergroup': userGroup,
    },
  );

  final response = await http.delete(uri);

  final data = jsonDecode(response.body);

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(data['message'] ?? 'Failed to delete blackout');
  }

  return data;
}

// Submit FAQ Question - Customer / Moderator
Future<Map<String, dynamic>> submitSupportQuestion({
  required String role,
  required String name,
  required String email,
  required String category,
  required String question,
  int? userid,
  File? attachment,
}) async {
  final uri = Uri.parse('$API_URL/support-question');

  final request = http.MultipartRequest('POST', uri);

  request.fields['role'] = role;
  request.fields['name'] = name;
  request.fields['email'] = email;
  request.fields['category'] = category;
  request.fields['question'] = question;

  if (userid != null) {
    request.fields['userid'] = userid.toString();
  }

  if (attachment != null) {
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        attachment.path,
      )
    );
  }

  final streamedResponse = await request.send();
  final response = await http.Response.fromStream(streamedResponse);

  final data = jsonDecode(response.body);

  if (response.statusCode != 200 && response.statusCode != 201) { 
    throw Exception(data['message'] ?? 'Failed to submit question');
  }

  return data;
}

// Admin - Fetch all submitted customer/moderator questions
Future<Map<String, dynamic>> fetchSupportQuestions({
  String role = 'all',
  String status = 'all',
  String search = '',
}) async {
  final params = {
    'role': role,
    'status': status,
    'search': search,
  };

  final uri = Uri.parse('$API_URL/admin/faq/questions').replace(
    queryParameters: params,
  );

  final response = await http.get(uri);
  final data = jsonDecode(response.body);

  if (response.statusCode < 200 ||
      response.statusCode >= 300 ||
      data['success'] == false) {
    throw Exception(data['message'] ?? 'Failed to fetch support questions');
  }

  return Map<String, dynamic>.from(data);
}

// Admin - Fetch FAQ stats
Future<Map<String, dynamic>> fetchFaqStats() async {
  final response = await http.get(
    Uri.parse('$API_URL/admin/faq/stats'),
  );

  final data = jsonDecode(response.body);

  if (response.statusCode < 200 ||
      response.statusCode >= 300 ||
      data['success'] == false) {
    throw Exception(data['message'] ?? 'Failed to fetch FAQ stats');
  }

  return Map<String, dynamic>.from(data);
}

// Public Customer FAQ - Fetch published FAQs
Future<Map<String, dynamic>> fetchPublishedFaqs({
  String category = 'all',
  String search = '',
}) async {
  final params = {
    'category': category,
    'search': search,
  };

  final uri = Uri.parse('$API_URL/faqs').replace(
    queryParameters: params,
  );

  final response = await http.get(uri);
  final data = jsonDecode(response.body);

  if (response.statusCode < 200 ||
      response.statusCode >= 300 ||
      data['success'] == false) {
    throw Exception(data['message'] ?? 'Failed to fetch published FAQs');
  }

  return Map<String, dynamic>.from(data);
}

// Admin - Fetch all published FAQs
Future<Map<String, dynamic>> fetchAdminPublishedFaqs() async {
  final response = await http.get(
    Uri.parse('$API_URL/admin/faq/published'),
  );

  final data = jsonDecode(response.body);

  if (response.statusCode < 200 ||
      response.statusCode >= 300 ||
      data['success'] == false) {
    throw Exception(data['message'] ?? 'Failed to fetch admin published FAQs');
  }

  return Map<String, dynamic>.from(data);
}

// Admin - Mark question as reviewed
Future<Map<String, dynamic>> reviewFaqQuestion(
  int questionid,
  Map<String, dynamic> payload,
) async {
  final response = await http.patch(
    Uri.parse('$API_URL/admin/faq/questions/$questionid/review'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(payload),
  );

  final data = jsonDecode(response.body);

  if (response.statusCode < 200 ||
      response.statusCode >= 300 ||
      data['success'] == false) {
    throw Exception(data['message'] ?? 'Failed to review FAQ question');
  }

  return Map<String, dynamic>.from(data);
}

// Admin - Publish question to FAQ
Future<Map<String, dynamic>> publishFaqQuestion(
  int questionid,
  Map<String, dynamic> payload,
) async {
  final response = await http.post(
    Uri.parse('$API_URL/admin/faq/questions/$questionid/publish'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(payload),
  );

  final data = jsonDecode(response.body);

  if (response.statusCode < 200 ||
      response.statusCode >= 300 ||
      data['success'] == false) {
    throw Exception(data['message'] ?? 'Failed to publish FAQ question');
  }

  return Map<String, dynamic>.from(data);
}

// Admin - Reject FAQ question
Future<Map<String, dynamic>> rejectFaqQuestion(
  int questionid,
  Map<String, dynamic> payload,
) async {
  final response = await http.patch(
    Uri.parse('$API_URL/admin/faq/questions/$questionid/reject'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(payload),
  );

  final data = jsonDecode(response.body);

  if (response.statusCode < 200 ||
      response.statusCode >= 300 ||
      data['success'] == false) {
    throw Exception(data['message'] ?? 'Failed to reject FAQ question');
  }

  return Map<String, dynamic>.from(data);
}

// Admin - Hide/Delete published FAQ
Future<Map<String, dynamic>> deletePublishedFaq(int faqid) async {
  final response = await http.delete(
    Uri.parse('$API_URL/admin/faq/published/$faqid'),
  );

  final data = jsonDecode(response.body);

  if (response.statusCode < 200 ||
      response.statusCode >= 300 ||
      data['success'] == false) {
    throw Exception(data['message'] ?? 'Failed to delete published FAQ');
  }

  return Map<String, dynamic>.from(data);
}

// Get property owner's PayPal ID
Future<Map<String, dynamic>> getPropertyOwnerPayPalId(int propertyId) async {
  try {
    final response = await http.get(
      Uri.parse('$API_URL/property/owner-paypal/$propertyId'),
      headers: await _authHeaders(),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to fetch property owner PayPal ID');
    }

    return {
      'payPalId': data['payPalId'],
      'ownerName': data['ownerName'],
    };
  } catch (error) {
    print('API error fetching PayPal ID: $error');
    rethrow;
  }
}

// Create PayPal Order
Future<Map<String, dynamic>> createPayPalOrder({
  required int reservationId,
  required int propertyId,
  required double amount,
  String currency = 'MYR',
}) async {
  final userid = await Session.getUserId();

  try {
    final response = await http.post(
      Uri.parse('$API_URL/paypal/create-order'),
      headers: {
        ...await _authHeaders(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'reservationId': reservationId,
        'propertyId': propertyId,
        'amount': double.parse(amount.toStringAsFixed(2)),
        'currency': currency,
        'userid': userid,
      }),
    );

    if (response.body.trim().startsWith('<!DOCTYPE') ||
        response.body.trim().startsWith('<html')) {
      throw Exception(
        'PayPal endpoint returned HTML instead of JSON. Please check backend /paypal/create-order.',
      );
    }

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode == 404) {
      throw Exception(
        'PayPal endpoint /paypal/create-order not found on backend.',
      );
    }

    if (data['success'] == false ||
        (response.statusCode != 200 && response.statusCode != 201)) {
      final errorMsg = data['message'] ?? 'Failed to create PayPal order';
      final errorDetail = data['error'] ?? '';

      throw Exception(
        errorDetail.toString().isNotEmpty
            ? '$errorMsg - $errorDetail'
            : errorMsg,
      );
    }

    if (data['orderId'] == null || data['approvalUrl'] == null) {
      throw Exception(
        'Invalid PayPal response. Missing orderId or approvalUrl.',
      );
    }

    return data;
  } catch (error) {
    print('API error creating PayPal order: $error');
    rethrow;
  }
}

// Capture PayPal Order
Future<Map<String, dynamic>> capturePayPalOrder(String orderId) async {
  try {
    final response = await http.post(
      Uri.parse('$API_URL/paypal/capture-order/$orderId'),
      headers: {
        ...await _authHeaders(),
        'Content-Type': 'application/json',
      },
    );

    if (response.body.trim().startsWith('<!DOCTYPE') ||
        response.body.trim().startsWith('<html')) {
      throw Exception(
        'PayPal capture endpoint returned HTML instead of JSON. Please check backend /paypal/capture-order/$orderId.',
      );
    }

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data['message'] ?? data['error'] ?? 'Failed to capture PayPal order',
      );
    }

    if (data['success'] == false) {
      throw Exception(
        data['message'] ?? data['error'] ?? 'PayPal capture failed',
      );
    }

    return data;
  } catch (error) {
    print('API error capturing PayPal order: $error');
    rethrow;
  }
}