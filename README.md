# 📊 Steem Curation AI

**Steem Curation AI** is a data pipeline and analytics system for collecting, evaluating, and modeling curation data on the [Steem blockchain](https://steem.io). This project combines SQL database design, Python data ingestion, and aggregate historic performance calculation to support intelligent curation strategies and in-depth post analysis.

## 🔧 Project Structure

```
Steem-Curation-AI-Project/
│
├── MySQL/
│   └── SteemSQL/
│       ├── schema/
│       │   ├── create_database.sql
│       │   ├── create_tables.sql
|       |   ├── create_triggers.sql
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
└── config.ini (gitignored)
└── README.md
```

## 📚 Features

- ✅ Full **MySQL schema** with referential integrity
- ✅ Modular **stored procedures** for insertion, updates, and analytics
- ✅ Triggers for live updates on reward and percentile data
- ✅ Python scripts for:
  - Pulling account, post, vote, and reward data from the Steem blockchain
  - Retrieving follower data from the Steem World API
  - Performing language analysis and text metrics
- ✅ Integrated with historic **Steem price** data to compute post value in Steem (at the time of payout)

## 🧱 Technologies Used

* **Steem Python Library** – Python interface for accessing the Steem blockchain API and performing account, post, vote, and reward operations
* **Python** – Data ingestion and analysis
* **BeautifulSoup / langdetect / enchant** – For text and language processing
* **MySQL** – Relational database schema, stored procedures, and event driven logic
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

3. Install Python dependencies:
   - It's recommended to use a virtual environment
   - Install required packages using:
   - 
   ```bash
   pip install -r requirements.txt
   ```
   
4. Configure your credentials:

   - Create a `config.ini` file (see `config_sample.ini` for format)
   - Update `CONFIG_PATH` to `config.ini` in `main.py`

5. Run the Python ingestion pipeline:

   ```bash
   python Python/Steem Download/main.py
   ```

## 📖 Documentation

- 📄[Schema Documentation](https://github.com/chrisp-bacon2024/Steem-Curation-AI-Project/blob/main/MySQL/docs/schema.md)
- ⚙️ [Procedure Documentation](https://github.com/chrisp-bacon2024/Steem-Curation-AI-Project/blob/main/MySQL/docs/procedures.md)
- 🧨 [Trigger Documentation](https://github.com/chrisp-bacon2024/Steem-Curation-AI-Project/blob/main/MySQL/docs/trigger.md)

## 📝 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

## 🧭 Future Plans
### Stage 1: Data Ingestion
The first stage of this project, building what is necessary for *data ingestion*, is completed. That being said, it will definitely take a while to collect all of the data. I estimate that it will take between 2 and 3 months to collect 1.5 years of data.
### Stage 2: Data Exploration and Model Selection
Once a good amount of data is collected, the next stage will be data exploration and model selection. I have a rough idea of the kind of models that will do well at this task (from my first attempt at this three years ago), but this project incorporates a lot more data features, and therefore different types of models may excel. The only way to find out is to explore the variety of options.
### Stage 3: Real World Implementation and Curation Analysis
After I have selected a model, I will begin to have it vote in real time on posts and analyze its performance on real world data. Previous models with less correlated features performed fairly well. My hope is that with the new features I've added, models will perform even better on real world data!

