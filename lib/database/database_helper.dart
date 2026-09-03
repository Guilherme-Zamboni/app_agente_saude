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
      version: 1,
      onCreate: _onCreate,
    );
  }

  // ... o restante do arquivo (_onCreate com todas as tabelas e índices)
  // continua exatamente igual, não precisa mudar nada abaixo daqui.

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
        FOREIGN KEY (territorio_id) REFERENCES territorio (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE familia (
        id TEXT PRIMARY KEY,
        domicilio_id TEXT NOT NULL,
        observacoes TEXT,
        ativo INTEGER NOT NULL DEFAULT 1,
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
        anotacoes_agente TEXT,
        ativo INTEGER NOT NULL DEFAULT 1,
        criado_em TEXT NOT NULL,
        atualizado_em TEXT NOT NULL,
        FOREIGN KEY (familia_id) REFERENCES familia (id)
      )
    ''');

    // familia_id sempre preenchido (toda visita pertence a uma família/domicílio).
    // morador_id só é preenchido quando for um acompanhamento extra individual;
    // nulo significa visita geral, cobrindo a família inteira.
    await db.execute('''
      CREATE TABLE visita (
        id TEXT PRIMARY KEY,
        familia_id TEXT NOT NULL,
        morador_id TEXT,
        data_visita TEXT NOT NULL,
        observacoes TEXT,
        FOREIGN KEY (familia_id) REFERENCES familia (id),
        FOREIGN KEY (morador_id) REFERENCES morador (id)
      )
    ''');

    await db.execute('CREATE INDEX idx_morador_nome ON morador (nome)');
    await db.execute('CREATE INDEX idx_morador_nome_mae ON morador (nome_da_mae)');
    await db.execute('CREATE INDEX idx_morador_familia ON morador (familia_id)');
    await db.execute('CREATE INDEX idx_domicilio_territorio ON domicilio (territorio_id)');
    await db.execute('CREATE INDEX idx_domicilio_endereco ON domicilio (rua, bairro)');
    await db.execute('CREATE INDEX idx_familia_domicilio ON familia (domicilio_id)');
    await db.execute('CREATE INDEX idx_visita_familia ON visita (familia_id)');
    await db.execute('CREATE INDEX idx_visita_morador ON visita (morador_id)');
  }
}