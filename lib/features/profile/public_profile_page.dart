import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart'; // To access 'supabase' client

class PublicProfilePage extends StatefulWidget {
  final String username;

  const PublicProfilePage({super.key, required this.username});

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPublicProfile();
  }

  Future<void> _fetchPublicProfile() async {
    try {
      // Remove the '@' if present
      final cleanUsername = widget.username.replaceAll('@', '');

      final data = await supabase
          .from('profiles')
          .select('full_name, username, avatar_url, created_at')
          .ilike('username', cleanUsername) // Case-insensitive match
          .maybeSingle();

      if (mounted) {
        setState(() {
          _profileData = data;
          _isLoading = false;
          if (data == null) _error = "Agent not found.";
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("AGENT IDENTITY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator(color: Color(0xFF4ECDC4))
            : _error != null
            ? Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 18))
            : _buildPublicIDCard(),
      ),
    );
  }

  Widget _buildPublicIDCard() {
    final name = _profileData?['full_name'] ?? 'Unknown';
    final handle = _profileData?['username'] ?? 'anon';
    final avatar = _profileData?['avatar_url'];
    final created = _profileData?['created_at'] != null
        ? DateTime.parse(_profileData!['created_at']).toString().split(' ')[0]
        : 'Unknown';

    return Container(
      width: 340,
      height: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black, width: 4),
        boxShadow: const [BoxShadow(color: Color(0xFF4ECDC4), offset: Offset(8, 8), blurRadius: 0)],
      ),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(width: 3),
                    image: avatar != null ? DecorationImage(image: NetworkImage(avatar), fit: BoxFit.cover) : null
                ),
                child: avatar == null ? const Icon(Icons.person, size: 40) : null,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    Text("@$handle", style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)),
                      child: const Text("VERIFIED AGENT", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              )
            ],
          ),
          Positioned(
            bottom: 0, left: 0,
            child: Text("JOINED: $created", style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          ),
          Positioned(
            bottom: -10, right: -10,
            child: Opacity(
              opacity: 0.3,
              child: Transform.rotate(
                angle: -0.2,
                child: Image.asset('assets/approved.png', width: 80), // Ensure asset exists
              ),
            ),
          )
        ],
      ),
    );
  }
}