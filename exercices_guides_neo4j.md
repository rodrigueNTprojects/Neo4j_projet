# Exercices Pratiques Guidés - Neo4j Ecommerce

## Préparation de l'Environnement

### Étape 1 : Placement des fichiers CSV

**Emplacement des fichiers CSV selon votre installation :**

#### Neo4j Desktop (Recommandé) :

1. Ouvrir Neo4j Desktop
2. Sélectionner votre base de données
3. Cliquer sur ... (trois points) → Open folder → Import
4. Copier tous vos fichiers CSV dans ce dossier

**Chemin typique :**

**Windows**: 
```
C:\Users\[VotreNom]\.Neo4jDesktop\relate-data\dbmss\dbms-[ID]\import\
```

**macOS**: 
```
/Users/[VotreNom]/Library/Application Support/Neo4j Desktop/Application/relate-data/dbmss/dbms-[ID]/import/
```

**Linux**: 
```
/home/[VotreNom]/.config/Neo4j Desktop/Application/relate-data/dbmss/dbms-[ID]/import/
```

#### Neo4j Server (Installation manuelle) :

**Windows**: `C:\neo4j\import\`

**macOS/Linux**: `/var/lib/neo4j/import/` ou `[NEO4J_HOME]/import/`

**Fichiers CSV à placer (11 fichiers) :**

```
import/
├── customers.csv
├── geolocation.csv
├── leads_closed.csv
├── leads_qualified.csv
├── order_items.csv
├── order_payments.csv
├── order_reviews.csv
├── orders.csv
├── product_category_name_translation.csv
├── products.csv
└── sellers.csv
```

---

### Étape 2 : Correction des fichiers CSV (IMPORTANT)

**Problème connu :** Le fichier `order_reviews.csv` contient des caractères `\` qui causent des erreurs de parsing CSV dans Neo4j.

**Solution :** Le script Python `clean_csv.py` est fourni séparément

**Exécution :**

1. Placez `clean_csv.py` dans le même dossier que vos fichiers CSV, dans le dossier `import`
2. Ouvrez un terminal/invite de commande dans ce dossier
3. Exécutez : `python clean_csv.py`
4. Vérifiez le message de confirmation

---

### Étape 3 : Configuration Neo4j

#### 3.1 Activer l'import CSV

**Dans Neo4j Desktop :**

1. Sélectionner votre base → ... → Settings
2. Ajouter ou vérifier ces lignes :

```properties
dbms.security.allow_csv_import_from_file_urls=true
```

3. Sauvegarder et redémarrer la base

**Dans Neo4j Server (fichier neo4j.conf) :**

```properties
# Autoriser l'import CSV
dbms.security.allow_csv_import_from_file_urls=true

# Chemin du dossier import (optionnel, défaut = import/)
dbms.directories.import=import
```

#### 3.2 Configuration de la mémoire (RECOMMANDÉ)

Pour améliorer les performances du chargement des fichiers volumineux (10-100 Mo) :

**Dans Neo4j Desktop :**

1. Sélectionner votre base → ... → Settings
2. Ajouter ces lignes :

```properties
dbms.memory.heap.initial_size=2g
dbms.memory.heap.max_size=4g
```

3. Sauvegarder et redémarrer

**Neo4j Server (neo4j.conf) :**

```properties
# Configuration mémoire recommandée pour fichiers 10-100 Mo
dbms.memory.heap.initial_size=2g
dbms.memory.heap.max_size=4g
```

**Notes :**
- Ces valeurs nécessitent au minimum 8 Go de RAM sur votre machine
- Ajustez selon vos ressources : 1g/2g pour 4 Go RAM, 512m/1g pour 2 Go RAM
- Redémarrer Neo4j après modification

---

### Étape 4 : Vérification de l'environnement

**Avant d'exécuter le script de chargement, vérifiez :**

```cypher
// 1. Vérifier la connexion
RETURN "Connexion OK" as status;

// 2. Vérifier que la base est vide (ou nettoyer)
MATCH (n) RETURN count(n) as node_count;

// Si node_count > 0 et que vous voulez repartir à zéro :
// MATCH (n) DETACH DELETE n;

// 3. Tester l'accès aux fichiers CSV
LOAD CSV FROM 'file:///customers.csv' AS row
RETURN row
LIMIT 1;
```

**Si erreur "Couldn't load the external resource" :**
- Vérifiez que les fichiers CSV sont dans le bon dossier `import/`
- Vérifiez les noms de fichiers (sensibles à la casse)
- Vérifiez la configuration `allow_csv_import_from_file_urls=true`

---

### Étape 5 : Exécution du script de chargement

**Préparation :**

1. Assurez-vous que le script de correction CSV a été exécuté
2. Assurez-vous que Neo4j est démarré
3. Ouvrez Neo4j Browser : http://localhost:7474

**Exécution du script :**

Le script de chargement (fourni séparément) contient plusieurs étapes.

1. Copiez le script complet dans Neo4j Browser
2. Exécutez (Ctrl+Enter ou Cmd+Enter)
3. Attendez la fin (peut prendre 5-10 minutes total)

**Progression attendue :**
- Étapes 1-3 : < 10 secondes
- Étapes 4-14 : 2-5 minutes (chargement des nœuds)
- Étapes 15-22 : 1-3 minutes (création des relations)

**Vérification du chargement réussi :**

Exécutez chaque requête à la fois :

```cypher
// Compter les nœuds par type
MATCH (n)
RETURN labels(n)[0] as node_type, COUNT(n) as count
ORDER BY count DESC;

// Compter les relations par type
MATCH ()-[r]->()
RETURN type(r) as relationship_type, COUNT(r) as count
ORDER BY count DESC;
```

**Résultats attendus :**

**Nombre de nœuds :**
- Customer: ~99,000
- Order: ~99,000
- OrderItem: ~112,000
- Product: ~32,000
- Seller: ~3,000
- Review: ~99,000
- Payment: ~103,000
- Category: ~71
- Geolocation: ~1,000,000
- QualifiedLead: ~8,000
- ClosedLead: ~8,000

**Nombre de relations :**
- PLACED: ~99,000
- CONTAINS: ~112,000
- OF_PRODUCT: ~112,000
- SOLD: ~112,000
- PAID_BY: ~103,000
- FOR_ORDER: ~99,000
- WROTE: ~99,000
- ABOUT: ~99,000
- BELONGS_TO: ~32,000
- LIVES_IN: ~99,000
- LOCATED_IN: ~3,000
- CONVERTED_TO: ~8,000
- BECAME: ~8,000

---

### Étape 6 : Résolution des problèmes courants

#### Erreur : "There's a field starting with a quote..."

**Cause :** Fichier `order_reviews.csv` non corrigé

**Solution :** Exécutez le script Python `clean_csv.py` de l'Étape 2

#### Erreur : "Out of memory" ou performances très lentes

**Cause :** Mémoire heap insuffisante

**Solution :**
1. Fermez les autres applications
2. Augmentez la mémoire heap (voir Étape 3.2)
3. Redémarrez Neo4j
4. Relancez le script

---

## Prérequis

**Avant de commencer les exercices :**

- Neo4j Desktop ou Neo4j Server installé et démarré
- Fichiers CSV corrigés et placés dans le dossier `import/`
- Configuration mémoire optimisée (2g/4g)
- Script de chargement exécuté avec succès
- Vérification: `MATCH (n) RETURN count(n);` retourne > 100,000

---

## Exercice 1 : Création de Nœuds et Propriétés

**Objectif :** Maîtriser la création de nœuds avec propriétés simples et complexes

### 1.1 Créer un nouveau client

```cypher
CREATE (c:Customer {
  customer_id: 'CUST_NEW_001',
  customer_unique_id: 'UUID_NEW_001',
  zip_code_prefix: '01310',
  city: 'sao paulo',
  state: 'SP'
})
RETURN c;
```

**Question :** Combien de propriétés a ce nœud ?

**Vérification :**
```cypher
MATCH (c:Customer {customer_id: 'CUST_NEW_001'})
RETURN properties(c);
```

---

### 1.2 Créer un produit avec propriétés numériques

```cypher
// 1. D'abord, vérifier les catégories existantes
MATCH (cat:Category)
RETURN cat.name, cat.name_english
LIMIT 10;

// 2. Créer un produit (sans catégorie pour l'instant)
CREATE (p:Product {
  product_id: 'PROD_NEW_001',
  name_length: 45,
  description_length: 280,
  photos_qty: 5,
  weight_g: 350.5,
  length_cm: 20.0,
  height_cm: 5.0,
  width_cm: 15.0
})
RETURN p;

// 3. Relier à une catégorie existante
MATCH (p:Product {product_id: 'PROD_NEW_001'})
MATCH (cat:Category {name: 'eletronicos'})
CREATE (p)-[:BELONGS_TO]->(cat)
RETURN p, cat;
```

**Challenge :** Créez un produit complet de la catégorie 'livros_tecnicos' avec vos propres valeurs.

---

## Exercice 2 : Création de Relations

**Objectif :** Comprendre comment créer des relations entre nœuds existants

### 2.1a Relier un client à une géolocalisation

```cypher
MATCH (c:Customer {customer_id: 'CUST_NEW_001'})
MATCH (g:Geolocation {zip_code_prefix: c.zip_code_prefix})
CREATE (c)-[:LIVES_IN]->(g)
RETURN c, g;
```

**Question :** Est-ce que la relation entre Customer et Geolocation a été créée? Vérifier s'il existe une instance de Geolocalisation dont zip_code_prefix = c.zip_code_prefix

---

### 2.1b Modifier le zip code du client et exécuter à nouveau 2.1a

```cypher
MATCH (c:Customer {customer_id: 'CUST_NEW_001'})
SET c.zip_code_prefix = '01310'
RETURN c;
```

**Question :** Cette relation est-elle dirigée ? Dans quel sens ?

---

### 2.2 Créer une commande complète

```cypher
// 1. Créer la commande
MATCH (c:Customer {customer_id: 'CUST_NEW_001'})
CREATE (o:Order {
  order_id: 'ORD_NEW_001',
  status: 'processing',
  purchase_timestamp: datetime()
})
CREATE (c)-[:PLACED]->(o)
RETURN c, o;

// 2. Créer un article de commande
MATCH (o:Order {order_id: 'ORD_NEW_001'})
MATCH (p:Product {product_id: 'PROD_NEW_001'})
CREATE (oi:OrderItem {
  order_item_id: 'OI_NEW_001',
  price: 299.99,
  freight_value: 25.00
})
CREATE (o)-[:CONTAINS]->(oi)
CREATE (oi)-[:OF_PRODUCT]->(p)
RETURN o, oi, p;
```

**Vérification :**
```cypher
MATCH path = (c:Customer)-[:PLACED]->()-[:CONTAINS]->()-[:OF_PRODUCT]->()
WHERE c.customer_id = 'CUST_NEW_001'
RETURN path;
```

---

## Exercice 3 : Requêtes MATCH - Recherche de Patterns

**Objectif :** Maîtriser la recherche de patterns dans le graphe

### 3.1 MATCH simple

```cypher
MATCH (c:Customer)
RETURN c.customer_id, c.city, c.state
LIMIT 10;
```

---

### 3.2 MATCH avec WHERE

```cypher
MATCH (c:Customer)
WHERE c.state = 'SP' AND c.city = 'sao paulo'
RETURN c.customer_id, c.city
LIMIT 10;
```

---

### 3.3 MATCH avec relations

```cypher
MATCH (c:Customer)-[:PLACED]->(o:Order)-[:CONTAINS]->(oi:OrderItem)
RETURN c.customer_id, o.order_id, count(oi) as items
LIMIT 10;
```

---

## Exercice 4 : Fonctions d'Agrégation

### 4.1 COUNT et SUM

```cypher
// Montant total dépensé par client
MATCH (c:Customer)-[:PLACED]->()-[:CONTAINS]->(oi:OrderItem)
RETURN c.customer_id,
       sum(oi.price) as total_spent,
       count(oi) as items_bought
ORDER BY total_spent DESC
LIMIT 10;
```

---

### 4.2 AVG et COLLECT

```cypher
// Prix moyen et liste des catégories par client
MATCH (c:Customer)-[:PLACED]->()-[:CONTAINS]->(oi:OrderItem)-[:OF_PRODUCT]->(p:Product)
RETURN c.customer_id,
       avg(oi.price) as avg_price,
       collect(DISTINCT p.category_name) as categories
LIMIT 10;
```

---

## Exercice 5 : Système de Recommandations

### 5.1 Produits les plus achetés

```cypher
// Produits les plus populaires avec détails
MATCH (p:Product)<-[:OF_PRODUCT]-(oi:OrderItem)<-[:CONTAINS]-(o:Order)
MATCH (p)-[:BELONGS_TO]->(cat:Category)
RETURN p.product_id,
       cat.name_english as category,
       count(DISTINCT o) as order_count,
       sum(oi.price) as total_revenue
ORDER BY order_count DESC
LIMIT 20;
```

---

### 5.2 Produits fréquemment achetés ensemble

```cypher
MATCH (p1:Product {product_id: '99a4788cb24856965c36a24e339b6058'})<-[:OF_PRODUCT]-(oi1:OrderItem)
MATCH (oi1)<-[:CONTAINS]-(o:Order)-[:CONTAINS]->(oi2:OrderItem)-[:OF_PRODUCT]->(p2:Product)
WHERE p1 <> p2
RETURN p2.product_id, count(DISTINCT o) as bought_together_count
ORDER BY bought_together_count DESC
LIMIT 5;
```

**Question :** Exécutez cette requête et décrivez son comportement

---

## Exercice 6 : Optimisation avec EXPLAIN et PROFILE

### 6.1 EXPLAIN - Analyser le plan d'exécution

```cypher
EXPLAIN
MATCH (c:Customer {customer_id: 'CUST_NEW_001'})
RETURN c;
```

---

### 6.2 PROFILE - Mesurer les performances

```cypher
PROFILE
MATCH (c:Customer)
WHERE c.state = 'SP'
RETURN count(c);
```

**Question :** Quelle est la couleur de la requête sur le navigateur Neo4j ?

---

### 6.3 Créer des index

```cypher
// Index pour améliorer les performances
CREATE INDEX customer_state_idx IF NOT EXISTS
FOR (c:Customer) ON (c.state);

// Re-tester avec PROFILE
PROFILE
MATCH (c:Customer {state: 'SP'})
RETURN count(c);
```

**Question :** Qu'est ce qui a changé entre l'exécution de la question 6.2 et cette exécution?

---

## Ressources Complémentaires

**Documentation :**
- Cypher Refcard : https://neo4j.com/docs/cypher-refcard/current/
- Query Tuning: https://neo4j.com/docs/cypher-manual/current/query-tuning/
- GraphAcademy : https://graphacademy.neo4j.com/

**Support:**
- Community Forum: https://community.neo4j.com/
- Stack Overflow: https://stackoverflow.com/questions/tagged/neo4j
