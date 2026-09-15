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
    final isAuthor = data['authorId'] == FirebaseAuth.instance.currentUser?.uid;
    final responses = FirebaseFirestore.instance
      .collection('topics')
      .doc(topic.id)
      .collection('responses');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          foregroundColor: Theme.of(context).colorScheme.primary,
          child: Text((data['category'] ?? '?')[0]),
        ),
        title: Text(data['title'] ?? 'Sem título', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${data['category'] ?? 'Geral'} • ${data['authorEmail'] ?? 'Usuário'}'),
        trailing: isAuthor
            ? IconButton(
                tooltip: 'Apagar tópico',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _apagarTopico(context),
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(alignment: Alignment.centerLeft, child: Text(data['description'] ?? '')),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: responses.snapshots(),
            builder: (context, snapshot) {
              final docs = [...(snapshot.data?.docs ?? [])];
              docs.sort((a, b) {
                final votosA = (a.data()['votesCount'] as num?)?.toInt() ?? 0;
                final votosB = (b.data()['votesCount'] as num?)?.toInt() ?? 0;
                if (votosA != votosB) return votosB.compareTo(votosA);
                final dataA = a.data()['createdAt'] as Timestamp?;
                final dataB = b.data()['createdAt'] as Timestamp?;
                return (dataB?.compareTo(dataA ?? Timestamp(0, 0)) ?? 0);
              });
              return Column(
                children: [
                  if (docs.isNotEmpty)
                    ...docs.map((doc) => ResponseTile(response: doc)),
                  if (!isAuthor)
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

  Future<void> _apagarTopico(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar tópico?'),
        content: const Text('O tópico e todas as respostas dele serão removidos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Apagar')),
        ],
      ),
    );
    if (confirmar != true) return;

    final respostas = await topic.reference.collection('responses').get();
    final batch = FirebaseFirestore.instance.batch();
    for (final resposta in respostas.docs) {
      final votos = await resposta.reference.collection('votes').get();
      for (final voto in votos.docs) {
        batch.delete(voto.reference);
      }
      batch.delete(resposta.reference);
    }
    batch.delete(topic.reference);
    await batch.commit();
  }
}

class ResponseTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> response;

  const ResponseTile({super.key, required this.response});

  @override
  Widget build(BuildContext context) {
    final data = response.data();
    final votes = (data['votesCount'] as num?)?.toInt() ?? 0;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final vote = response.reference.collection('votes').doc(userId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userId == null ? null : vote.snapshots(),
      builder: (context, snapshot) {
        final voted = snapshot.data?.exists ?? false;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.reply, size: 18),
          ),
          title: Text(data['text'] ?? ''),
          subtitle: Text(data['authorEmail'] ?? 'Usuário'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => _alternarVoto(context, response.reference, vote),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Icon(
                        voted ? Icons.favorite : Icons.favorite_border,
                        color: voted ? const Color(0xFFC53D4A) : Colors.grey,
                        size: 21,
                      ),
                    ),
                  ),
                  if (data['authorId'] == userId)
                    IconButton(
                      tooltip: 'Apagar resposta',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _apagarResposta(context, response.reference),
                    ),
                ],
              ),
              Text('$votes', style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        );
      },
    );
  }

  Future<void> _alternarVoto(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> response,
    DocumentReference<Map<String, dynamic>> vote,
  ) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final responseSnapshot = await transaction.get(response);
        final voteSnapshot = await transaction.get(vote);
        final currentVotes = (responseSnapshot.data()?['votesCount'] as num?)?.toInt() ?? 0;
        if (voteSnapshot.exists) {
          transaction.delete(vote);
          transaction.update(response, {'votesCount': currentVotes > 0 ? currentVotes - 1 : 0});
        } else {
          transaction.set(vote, {'createdAt': FieldValue.serverTimestamp()});
          transaction.update(response, {'votesCount': currentVotes + 1});
        }
      });
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível registrar o voto.')),
      );
    }
  }

  Future<void> _apagarResposta(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> response,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar resposta?'),
        content: const Text('Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Apagar')),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      final votos = await response.collection('votes').get();
      final batch = FirebaseFirestore.instance.batch();
      for (final voto in votos.docs) {
        batch.delete(voto.reference);
      }
      batch.delete(response);
      await batch.commit();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível apagar a resposta.')),
      );
    }
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
    final topico = await FirebaseFirestore.instance.collection('topics').doc(topicId).get();
    if (topico.data()?['authorId'] == user.uid) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O autor não pode responder ao próprio tópico.')),
      );
      return;
    }
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
          'votesCount': 0,
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
