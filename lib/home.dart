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
  final _pesquisaController = TextEditingController();
  String _categoria = 'Todas';
  String _termoBusca = '';
  bool _meusTopicos = false;
  bool _pesquisaAtiva = false;

  static const _categorias = ['Todas', 'Dúvidas', 'Estudos', 'Eventos', 'Avisos'];

  Query<Map<String, dynamic>> get _consulta {
    return _topics.orderBy('createdAt', descending: true);
  }

  @override
  void dispose() {
    _pesquisaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(child: _painelLateral()),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ClassHub'),
            Text('Conecte-se, pergunte e compartilhe', style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final painel = _painelLateral();
          final conteudo = _listaTopicos();
          if (constraints.maxWidth >= 800) {
            return Row(children: [SizedBox(width: 248, child: painel), Expanded(child: conteudo)]);
          }
          return conteudo;
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _novoTopico,
        icon: const Icon(Icons.add),
        label: const Text('Novo tópico'),
      ),
    );
  }

  Widget _painelLateral() {
    return Material(
      color: const Color(0xFFFFF1EC),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
          children: [
            Row(children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.forum_rounded, color: Colors.white)),
              const SizedBox(width: 12),
              const Text('Explorar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 28),
            const Text('VISUALIZAÇÃO', style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 8),
            _menuItem(Icons.grid_view_rounded, 'Todos os tópicos', _categoria == 'Todas' && !_meusTopicos, () => _selecionarFiltro('Todas', false)),
            _menuItem(Icons.person_outline_rounded, 'Meus tópicos', _meusTopicos, () => _selecionarFiltro(_categoria, true)),
            _menuItem(Icons.search_rounded, 'Pesquisar tópicos', _pesquisaAtiva, _abrirPesquisa),
            const SizedBox(height: 24),
            const Text('CATEGORIAS', style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 8),
            ..._categorias.skip(1).map((categoria) => _menuItem(Icons.circle, categoria, _categoria == categoria && !_meusTopicos, () => _selecionarFiltro(categoria, false), smallIcon: true)),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, bool selected, VoidCallback onTap, {bool smallIcon = false}) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      selected: selected,
      selectedTileColor: const Color(0xFFFFDCD4),
      leading: Icon(icon, size: smallIcon ? 10 : 20, color: selected ? Theme.of(context).colorScheme.primary : Colors.black54),
      title: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.w500)),
      onTap: onTap,
    );
  }

  void _selecionarFiltro(String categoria, bool meusTopicos) {
    setState(() {
      _categoria = categoria;
      _meusTopicos = meusTopicos;
      _pesquisaAtiva = false;
    });
    if (MediaQuery.sizeOf(context).width < 800) Navigator.pop(context);
  }

  void _abrirPesquisa() {
    setState(() => _pesquisaAtiva = true);
    if (MediaQuery.sizeOf(context).width < 800) Navigator.pop(context);
  }

  Widget _listaTopicos() {
    return Column(
      children: [
        if (_pesquisaAtiva)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: TextField(
              controller: _pesquisaController,
              autofocus: true,
              onChanged: (value) => setState(() => _termoBusca = value.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar por título, descrição ou autor',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Fechar pesquisa',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() {
                    _pesquisaAtiva = false;
                    _termoBusca = '';
                    _pesquisaController.clear();
                  }),
                ),
              ),
            ),
          ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _consulta.snapshots(),
            builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Não foi possível carregar os tópicos.'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final userId = FirebaseAuth.instance.currentUser?.uid;
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data();
          final categoria = (data['category'] ?? '').toString().trim().toLowerCase();
          final texto = '${data['title'] ?? ''} ${data['description'] ?? ''} ${data['authorEmail'] ?? ''}'.toLowerCase();
          final categoriaOk = _categoria == 'Todas' || categoria == _categoria.toLowerCase();
          final autorOk = !_meusTopicos || data['authorId'] == userId;
          final buscaOk = _termoBusca.isEmpty || texto.contains(_termoBusca);
          return categoriaOk && autorOk && buscaOk;
        }).toList();
        if (docs.isEmpty) return const Center(child: Text('Nenhum tópico encontrado.'));
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
          itemCount: docs.length,
          itemBuilder: (_, index) => TopicCard(topic: docs[index]),
        );
            },
          ),
        ),
      ],
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
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(),
        collapsedShape: const RoundedRectangleBorder(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          foregroundColor: Theme.of(context).colorScheme.primary,
          child: Text((data['category'] ?? '?')[0]),
        ),
        title: Text(data['title'] ?? 'Sem título', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${data['category'] ?? 'Geral'}  |  ${data['authorEmail'] ?? 'Usuário'}'),
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

    try {
      final respostas = await topic.reference.collection('responses').get();
      final referencias = <DocumentReference<Map<String, dynamic>>>[];
      for (final resposta in respostas.docs) {
        final votos = await resposta.reference.collection('votes').get();
        referencias.addAll(votos.docs.map((voto) => voto.reference));
        referencias.add(resposta.reference);
      }
      referencias.add(topic.reference);

      for (var inicio = 0; inicio < referencias.length; inicio += 400) {
        final fim = (inicio + 400).clamp(0, referencias.length);
        final batch = FirebaseFirestore.instance.batch();
        for (final referencia in referencias.sublist(inicio, fim)) {
          batch.delete(referencia);
        }
        await batch.commit();
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível apagar o tópico. Tente novamente.')),
      );
    }
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
