import 'dart:convert';
import 'dart:io';

void main() async {
  final supabaseUrl = 'https://jluuobtzylejiahbelgp.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpsdXVvYnR6eWxlamlhaGJlbGdwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI3Mjg0NTksImV4cCI6MjA4ODMwNDQ1OX0.ziUtvEdXw3w0yqPpRwk6-rWrIi1qVTKpkZFcxyl7gRE';

  final client = HttpClient();

  // Helper function
  Future<String> fetchUrl(String url) async {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.add('apikey', anonKey);
    request.headers.add('Authorization', 'Bearer $anonKey');
    final response = await request.close();
    return await response.transform(utf8.decoder).join();
  }

  // Check OpenAPI spec to get full schema
  print('=== FETCHING OPENAPI SPEC (table definitions) ===');
  try {
    final spec = await fetchUrl('$supabaseUrl/rest/v1/?apikey=$anonKey');
    final json = jsonDecode(spec);
    final definitions = json['definitions'] as Map<String, dynamic>?;
    if (definitions != null) {
      for (var tableName in definitions.keys) {
        final table = definitions[tableName];
        final properties = table['properties'] as Map<String, dynamic>?;
        if (properties != null) {
          print('\n--- $tableName ---');
          for (var col in properties.keys) {
            final colDef = properties[col];
            final type = colDef['type'] ?? colDef['format'] ?? 'unknown';
            final desc = colDef['description'] ?? '';
            final defaultVal = colDef['default'] ?? '';
            print('  $col: $type ${desc.isNotEmpty ? "($desc)" : ""} ${defaultVal.toString().isNotEmpty ? "[default: $defaultVal]" : ""}');
          }
        }
      }
    } else {
      print('Could not parse definitions from OpenAPI spec.');
      print('Raw keys: ${json.keys}');
    }
  } catch (e) {
    print('Error fetching OpenAPI spec: $e');
  }

  client.close();
}
