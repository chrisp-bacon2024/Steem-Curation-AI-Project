# 📊 Steem Curation AI

**Steem Curation AI** is a full-stack data pipeline and analytics system for tracking, evaluating, and modeling curation behavior on the [Steem blockchain](https://steem.io). This project combines SQL database design, Python data ingestion, and reward calculation to support intelligent curation strategies and in-depth post analysis.

## 🔧 Project Structure

```
Steem-Curation-AI-Project/
│
├── MySQL/
│   └── SteemSQL/
│       ├── schema/
│       │   ├── create_tables.sql
│       │   ├── create_triggers.sql
│       │   └── Procedures/
│       │       ├── Insertion/
│       │       ├── create_update_procedures.sql
│       │       └── create_utility_procedures.sql
│       │       
│       └── docs/
│           ├── schema.md
│           ├── procedures.md
|           └── triggers.md
│
├── Python/
│   └── Steem Download/
│       ├── config/
|       |   └── database_config.ini (gitignored)
│       ├── data/
│       |   └── ...
|       ├── SteemSQL/
|       |   └── connection.py
|       ├── steemstream
|       |   ├── process/...
|       |   ├── account.py
|       |   ├── stream_blocks.py
|       |   └── stream_prices.py
|       └── steemutils
|       |   ├── block_lookup.py
|       |   ├── language.py
|       |   ├── markdown_analysis.py
|       |   └── time.py
|       └── main.py
│
└── README.md
```

## 📚 Features

- ✅ Full **MySQL schema** with referential integrity
- ✅ Modular **stored procedures** for insertion, updates, and analytics
- ✅ Triggers for live updates on reward and percentile data
- ✅ Python scripts for:
  - Pulling post, vote, and reward data from the Steem blockchain
  - Performing language analysis and text metrics
  - Logging historic curation and author performance
- ✅ Integrated with historic **Steem price** data to compute post value in USD

## 🧱 Technologies Used

- **Steem** – Decentralized blockchain platform for content and rewards

* **MySQL** – Relational database schema and stored procedures
* **Python** – Data ingestion and analysis
* **BeautifulSoup / langdetect / enchant** – For text and language processing
* **GitHub** – Version control and collaboration

## 🚀 Getting Started

1. Clone the repo:

   ```bash
   git clone https://github.com/chrisp-bacon2024/Steem-Curation-AI-Project.git
   cd Steem-Curation-AI-Project
   ```

2. Set up your database:

   - Run the SQL files in `MySQL/SteemSQL/schema/` using MySQL Workbench or CLI
   - Make sure you have MySQL 8.x installed

3. Configure your credentials:

   - Create a `config.ini` file (see `config_sample.ini` for format)

4. Run the Python ingestion pipeline:

   ```bash
   python Python/main.py
   ```

## 📖 Documentation

- 📄[Schema Documentation](https://github.com/chrisp-bacon2024/Steem-Curation-AI-Project/blob/main/MySQL/docs/schema.md)
- ⚙️ [Procedure Documentation](https://github.com/chrisp-bacon2024/Steem-Curation-AI-Project/blob/main/MySQL/docs/procedures.md)
- 🧨 [Trigger Documentation](https://github.com/chrisp-bacon2024/Steem-Curation-AI-Project/blob/main/MySQL/docs/trigger.md)

## 📝 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

