import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'authentication.dart';
import 'login.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return const TopicsPage();
  }
}

class TopicsPage extends StatefulWidget {
  const TopicsPage({super.key});

  @override
  State<TopicsPage> createState() => _TopicsPageState();
}

class _TopicsPageState extends State<TopicsPage> {
  final _topics = FirebaseFirestore.instance.collection('topics');
  String _categoria = 'Todas';
  bool _meusTopicos = false;

  Query<Map<String, dynamic>> get _consulta {
    Query<Map<String, dynamic>> query = _topics.orderBy('createdAt', descending: true);
    if (_categoria != 'Todas') {
      query = query.where('category', isEqualTo: _categoria);
    }
    if (_meusTopicos) {
      query = query.where(
        'authorId',
        isEqualTo: FirebaseAuth.instance.currentUser?.uid,
      );
    }
    return query;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ClassHub'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('sessao_ativa', false);
              await AuthenticationHelper().signOut();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const Login()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _filtros(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _consulta.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Não foi possível carregar os tópicos.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('Nenhum tópico encontrado.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (_, index) => TopicCard(topic: docs[index]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _novoTopico,
        icon: const Icon(Icons.add),
        label: const Text('Novo tópico'),
      ),
    );
  }

  Widget _filtros() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _categoria,
              decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
              items: ['Todas', 'Dúvidas', 'Estudos', 'Eventos', 'Avisos']
                  .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: (value) => setState(() => _categoria = value!),
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Meus tópicos'),
            selected: _meusTopicos,
            onSelected: (value) => setState(() => _meusTopicos = value),
          ),
        ],
      ),
    );
  }

  Future<void> _novoTopico() async {
    final titulo = TextEditingController();
    final descricao = TextEditingController();
    String categoria = 'Dúvidas';
    final enviar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Criar tópico'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titulo, decoration: const InputDecoration(labelText: 'Título')),
              TextField(controller: descricao, maxLines: 3, decoration: const InputDecoration(labelText: 'Descreva sua dúvida ou ideia')),
              DropdownButton<String>(value: categoria, items: ['Dúvidas', 'Estudos', 'Eventos', 'Avisos'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) => setDialogState(() => categoria = value!)),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Publicar'))],
      ),
    );
    if (enviar != true || titulo.text.trim().isEmpty || descricao.text.trim().isEmpty) return;
    final user = FirebaseAuth.instance.currentUser!;
    await _topics.add({
      'title': titulo.text.trim(),
      'description': descricao.text.trim(),
      'category': categoria,
      'authorId': user.uid,
      'authorEmail': user.email ?? 'Usuário',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

class TopicCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> topic;

  const TopicCard({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    final data = topic.data();
    final responses = FirebaseFirestore.instance
        .collection('topics')
        .doc(topic.id)
        .collection('responses')
        .orderBy('createdAt');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(child: Text((data['category'] ?? '?')[0])),
        title: Text(data['title'] ?? 'Sem título', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${data['category'] ?? 'Geral'} • ${data['authorEmail'] ?? 'Usuário'}'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(alignment: Alignment.centerLeft, child: Text(data['description'] ?? '')),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: responses.snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              return Column(
                children: [
                  if (docs.isNotEmpty)
                    ...docs.map((doc) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.reply, size: 18),
                          title: Text(doc.data()['text'] ?? ''),
                          subtitle: Text(doc.data()['authorEmail'] ?? 'Usuário'),
                        )),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: ResponseButton(topicId: topic.id),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class ResponseButton extends StatelessWidget {
  final String topicId;

  const ResponseButton({super.key, required this.topicId});

  Future<void> _responder(BuildContext context) async {
    final controller = TextEditingController();
    final texto = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Responder ao tópico'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Digite sua resposta'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Enviar')),
        ],
      ),
    );
    if (texto == null || texto.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser!;
    final resposta = FirebaseFirestore.instance
        .collection('topics')
        .doc(topicId)
        .collection('responses')
        .doc(user.uid);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final existente = await transaction.get(resposta);
        if (existente.exists) throw StateError('Você já respondeu a este tópico.');
        transaction.set(resposta, {
          'text': texto,
          'authorId': user.uid,
          'authorEmail': user.email ?? 'Usuário',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is StateError ? e.message : 'Erro ao enviar resposta.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _responder(context),
      icon: const Icon(Icons.reply),
      label: const Text('Responder uma vez'),
    );
  }
}
