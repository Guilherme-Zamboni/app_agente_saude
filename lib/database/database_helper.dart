import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import '../security/secure_key_manager.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'app_agente_saude.db');
    final chave = await SecureKeyManager.obterOuCriarChave();

    return await openDatabase(
      path,
      password: chave,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE territorio (
        id TEXT PRIMARY KEY,
        nome TEXT NOT NULL,
        agente_id TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE domicilio (
        id TEXT PRIMARY KEY,
        territorio_id TEXT NOT NULL,
        rua TEXT NOT NULL,
        numero TEXT NOT NULL,
        bairro TEXT NOT NULL,
        complemento TEXT,
        ativo INTEGER NOT NULL DEFAULT 1,
        pos_x REAL,
        pos_y REAL,
        criado_em TEXT NOT NULL DEFAULT '',
        atualizado_em TEXT NOT NULL DEFAULT '',
        sincronizado INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (territorio_id) REFERENCES territorio (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE familia (
        id TEXT PRIMARY KEY,
        domicilio_id TEXT NOT NULL,
        observacoes TEXT,
        ativo INTEGER NOT NULL DEFAULT 1,
        atualizado_em TEXT NOT NULL DEFAULT '',
        sincronizado INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (domicilio_id) REFERENCES domicilio (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE morador (
        id TEXT PRIMARY KEY,
        familia_id TEXT NOT NULL,
        nome TEXT NOT NULL,
        nome_da_mae TEXT NOT NULL,
        data_nascimento TEXT NOT NULL,
        cpf TEXT,
        comorbidades TEXT,
        gestante INTEGER NOT NULL DEFAULT 0,
        acamado INTEGER NOT NULL DEFAULT 0,
        anotacoes_agente TEXT,
        ativo INTEGER NOT NULL DEFAULT 1,
        criado_em TEXT NOT NULL,
        atualizado_em TEXT NOT NULL,
        sincronizado INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (familia_id) REFERENCES familia (id)
      )
    ''');

    await _criarTabelaVisita(db);

    await db.execute('''
      CREATE TABLE controle_sync (
        chave TEXT PRIMARY KEY,
        valor TEXT
      )
    ''');

    await _criarIndices(db);
  }

  Future<void> _criarTabelaVisita(Database db, {String nome = 'visita'}) async {
    await db.execute('''
      CREATE TABLE $nome (
        id TEXT PRIMARY KEY,
        domicilio_id TEXT NOT NULL,
        familia_id TEXT,
        morador_id TEXT,
        data_visita TEXT NOT NULL,
        resultado TEXT NOT NULL DEFAULT 'realizada',
        observacoes TEXT,
        ativo INTEGER NOT NULL DEFAULT 1,
        atualizado_em TEXT NOT NULL DEFAULT '',
        sincronizado INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (domicilio_id) REFERENCES domicilio (id),
        FOREIGN KEY (familia_id) REFERENCES familia (id),
        FOREIGN KEY (morador_id) REFERENCES morador (id)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int versaoAntiga, int versaoNova) async {
    if (versaoAntiga < 2) {
      for (final tabela in ['domicilio', 'familia', 'morador', 'visita']) {
        await db.execute(
            'ALTER TABLE $tabela ADD COLUMN sincronizado INTEGER NOT NULL DEFAULT 0');
      }
      for (final tabela in ['domicilio', 'familia', 'visita']) {
        await db.execute(
            "ALTER TABLE $tabela ADD COLUMN atualizado_em TEXT NOT NULL DEFAULT ''");
      }
      await db.execute('''
        CREATE TABLE IF NOT EXISTS controle_sync (
          chave TEXT PRIMARY KEY,
          valor TEXT
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_domicilio_sync ON domicilio (sincronizado)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_familia_sync ON familia (sincronizado)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_morador_sync ON morador (sincronizado)');
    }

    if (versaoAntiga < 3) {
      await db.execute(
          'ALTER TABLE visita ADD COLUMN ativo INTEGER NOT NULL DEFAULT 1');
    }

    if (versaoAntiga < 4) {
      await db.execute(
          'ALTER TABLE morador ADD COLUMN acamado INTEGER NOT NULL DEFAULT 0');
    }

    if (versaoAntiga < 5) {
      // data de cadastro do domicílio (usada no relatório mensal)
      await db.execute(
          "ALTER TABLE domicilio ADD COLUMN criado_em TEXT NOT NULL DEFAULT ''");
      await db.execute(
          "UPDATE domicilio SET criado_em = atualizado_em WHERE criado_em = ''");

      // reconstrói a tabela de visitas: família opcional, domicílio obrigatório
      await _criarTabelaVisita(db, nome: 'visita_nova');
      await db.execute('''
        INSERT INTO visita_nova
          (id, domicilio_id, familia_id, morador_id, data_visita, resultado,
           observacoes, ativo, atualizado_em, sincronizado)
        SELECT v.id, f.domicilio_id, v.familia_id, v.morador_id, v.data_visita,
               'realizada', v.observacoes, v.ativo, v.atualizado_em, 0
        FROM visita v
        INNER JOIN familia f ON f.id = v.familia_id
      ''');
      await db.execute('DROP TABLE visita');
      await db.execute('ALTER TABLE visita_nova RENAME TO visita');
      await _criarIndicesVisita(db);
    }
  }

  Future<void> _criarIndices(Database db) async {
    await db.execute('CREATE INDEX idx_morador_nome ON morador (nome)');
    await db.execute('CREATE INDEX idx_morador_nome_mae ON morador (nome_da_mae)');
    await db.execute('CREATE INDEX idx_morador_familia ON morador (familia_id)');
    await db.execute('CREATE INDEX idx_domicilio_territorio ON domicilio (territorio_id)');
    await db.execute('CREATE INDEX idx_domicilio_endereco ON domicilio (rua, numero)');
    await db.execute('CREATE INDEX idx_familia_domicilio ON familia (domicilio_id)');

    await db.execute('CREATE INDEX idx_domicilio_sync ON domicilio (sincronizado)');
    await db.execute('CREATE INDEX idx_familia_sync ON familia (sincronizado)');
    await db.execute('CREATE INDEX idx_morador_sync ON morador (sincronizado)');

    await _criarIndicesVisita(db);
  }

  Future<void> _criarIndicesVisita(Database db) async {
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_visita_domicilio ON visita (domicilio_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_visita_familia ON visita (familia_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_visita_morador ON visita (morador_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_visita_sync ON visita (sincronizado)');
  }

  Future<DateTime?> ultimaSincronizacao() async {
    final db = await database;
    final resultado = await db.query(
      'controle_sync',
      where: 'chave = ?',
      whereArgs: ['ultima_sync'],
    );
    if (resultado.isEmpty) return null;
    final valor = resultado.first['valor'] as String?;
    return valor == null ? null : DateTime.tryParse(valor);
  }

  Future<void> registrarSincronizacao(DateTime momento) async {
    final db = await database;
    await db.insert(
      'controle_sync',
      {'chave': 'ultima_sync', 'valor': momento.toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}