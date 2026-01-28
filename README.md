# Database Project – Women’s World Cup (Part II)

This repository contains **Part II of the Databases I final project (2023–2024)**, focused on the implementation of **integrity and business rules** for a Women’s World Cup relational database using **SQL triggers and auxiliary database objects**.

The project extends a provided conceptual and physical data model by enforcing real-world constraints through database-level logic.

---

## Repository Structure

```
worldcup-database-sql-rules/
│
├── PROJETO_SQL.sql         # SQL script implementing integrity & business rules
├── create_mundial.sql      # SQL script to generate database
├── test_triggers.sql       # SQL script to test triggers implemented
├── Mundial.cdm             # Conceptual Database
├── Mundial.pdm             # Physical Database
└── README.md
```

---

## Project Context

This delivery builds upon the database developed in **Part I** of the project.  
A base data model and SQL script were provided to ensure consistency across groups.

The objective of Part II is to **enrich the database with integrity and business rules**, ensuring that invalid operations are prevented and that domain logic is enforced directly at the database level.

---

## Implemented Business Rules

The following rules were implemented using **triggers**, complemented where necessary by **functions, procedures, and constraints**:

1. A player can only be summoned if she belongs to one of the countries participating in the match.
2. A referee cannot officiate a match involving her/his own country.
3. When a second yellow card is given to the same player in a match, a red card event is automatically inserted.
4. A goal can only be registered if the scoring player was on the field at the time of the event.
5. When a replacement occurs, the system verifies:
   - The player leaving was on the field;
   - The player entering was on the bench and available;
   - Both players belong to the same team;
   - Both players are part of the same match.

If any rule is violated, the corresponding record is not inserted and an informative message is returned.

---

## Technologies Used

- **SQL**
- Triggers
- Stored Procedures
- Functions
- Integrity Constraints

The script is compatible with standard relational database systems (minor syntax adjustments may be required depending on the DBMS).

---

## How to Execute

1. Create a new database in your SQL environment
2. Load the base schema provided in Part I (if required)
3. Execute the project SQL script:

```sql
SOURCE PROJETO_SQL.sql;
```

or run the file directly in your SQL editor.

---

## Testing Considerations

- The implementation supports **both single-row and batch operations**
- In batch operations containing valid and invalid rows:
  - Valid rows are inserted/updated
  - Invalid rows are ignored without rolling back the entire operation
- The triggers are designed to allow professor-provided test cases to execute correctly

---

## Academic Information

- Course: **Databases I**
- Academic Year: **2023–2024**
- Project: **Women’s World Cup Database**
- Delivery: **Part II – Integrity & Business Rules**

---

## License

This project is intended strictly for **academic purposes**.
