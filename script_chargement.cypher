// ============================================================
// SCRIPT OPTIMISÉ NEO4J 4.4+ - FICHIERS 10-100 Mo
// ============================================================
// Utilise CALL { ... } IN TRANSACTIONS (syntaxe moderne)
// PRÉREQUIS: Placer tous les fichiers CSV dans le dossier neo4j/import/

// ===== ÉTAPE 0: NETTOYAGE COMPLET =====
// IMPORTANT: Décommentez pour supprimer toutes les données existantes
MATCH (n) DETACH DELETE n;
// CALL apoc.schema.assert({}, {});  // Si APOC installé

// ===== ÉTAPE 1: SUPPRESSION DES CONTRAINTES EXISTANTES =====
DROP CONSTRAINT customer_id_unique IF EXISTS;
DROP CONSTRAINT product_id_unique IF EXISTS;
DROP CONSTRAINT order_id_unique IF EXISTS;
DROP CONSTRAINT seller_id_unique IF EXISTS;
DROP CONSTRAINT review_id_unique IF EXISTS;
DROP CONSTRAINT order_item_id_unique IF EXISTS;
DROP CONSTRAINT qualified_lead_id_unique IF EXISTS;
DROP CONSTRAINT closed_lead_id_unique IF EXISTS;
DROP CONSTRAINT category_name_unique IF EXISTS;
DROP CONSTRAINT geolocation_zip_unique IF EXISTS;

// ===== ÉTAPE 2: CRÉATION DES CONTRAINTES D'UNICITÉ =====
CREATE CONSTRAINT customer_id_unique IF NOT EXISTS
FOR (c:Customer) REQUIRE c.customer_id IS UNIQUE;

CREATE CONSTRAINT product_id_unique IF NOT EXISTS
FOR (p:Product) REQUIRE p.product_id IS UNIQUE;

CREATE CONSTRAINT order_id_unique IF NOT EXISTS
FOR (o:Order) REQUIRE o.order_id IS UNIQUE;

CREATE CONSTRAINT seller_id_unique IF NOT EXISTS
FOR (s:Seller) REQUIRE s.seller_id IS UNIQUE;

CREATE CONSTRAINT review_id_unique IF NOT EXISTS
FOR (r:Review) REQUIRE r.review_id IS UNIQUE;

CREATE CONSTRAINT order_item_id_unique IF NOT EXISTS
FOR (oi:OrderItem) REQUIRE oi.order_item_id IS UNIQUE;

CREATE CONSTRAINT qualified_lead_id_unique IF NOT EXISTS
FOR (ql:QualifiedLead) REQUIRE ql.mql_id IS UNIQUE;

CREATE CONSTRAINT closed_lead_id_unique IF NOT EXISTS
FOR (cl:ClosedLead) REQUIRE cl.mql_id IS UNIQUE;

CREATE CONSTRAINT category_name_unique IF NOT EXISTS
FOR (cat:Category) REQUIRE cat.name IS UNIQUE;

CREATE CONSTRAINT geolocation_zip_unique IF NOT EXISTS
FOR (g:Geolocation) REQUIRE g.zip_code_prefix IS UNIQUE;

// ===== ÉTAPE 3: CRÉATION DES INDEX DE PERFORMANCE =====
CREATE INDEX customer_state IF NOT EXISTS
FOR (c:Customer) ON (c.state);

CREATE INDEX customer_city IF NOT EXISTS
FOR (c:Customer) ON (c.city);

CREATE INDEX customer_zip IF NOT EXISTS
FOR (c:Customer) ON (c.zip_code_prefix);

CREATE INDEX product_category IF NOT EXISTS
FOR (p:Product) ON (p.category_name);

CREATE INDEX order_status IF NOT EXISTS
FOR (o:Order) ON (o.status);

CREATE INDEX order_customer IF NOT EXISTS
FOR (o:Order) ON (o.customer_id);

CREATE INDEX seller_city IF NOT EXISTS
FOR (s:Seller) ON (s.city);

CREATE INDEX seller_zip IF NOT EXISTS
FOR (s:Seller) ON (s.zip_code_prefix);

CREATE INDEX review_score IF NOT EXISTS
FOR (r:Review) ON (r.score);

CREATE INDEX review_order IF NOT EXISTS
FOR (r:Review) ON (r.order_id);

CREATE INDEX order_item_order IF NOT EXISTS
FOR (oi:OrderItem) ON (oi.order_id);

CREATE INDEX order_item_product IF NOT EXISTS
FOR (oi:OrderItem) ON (oi.product_id);

CREATE INDEX order_item_seller IF NOT EXISTS
FOR (oi:OrderItem) ON (oi.seller_id);

CREATE INDEX payment_order IF NOT EXISTS
FOR (p:Payment) ON (p.order_id);

CREATE INDEX closed_lead_seller IF NOT EXISTS
FOR (cl:ClosedLead) ON (cl.seller_id);

// ===== ÉTAPE 4: CHARGEMENT DES GÉOLOCALISATIONS =====
:auto LOAD CSV WITH HEADERS FROM 'file:///geolocation.csv' AS row
CALL {
  WITH row
  MERGE (g:Geolocation {zip_code_prefix: row.geolocation_zip_code_prefix})
  ON CREATE SET
    g.lat = toFloat(row.geolocation_lat),
    g.lng = toFloat(row.geolocation_lng),
    g.city = row.geolocation_city,
    g.state = row.geolocation_state
} IN TRANSACTIONS OF 500 ROWS;

// ===== ÉTAPE 5: CHARGEMENT DES CATÉGORIES =====
:auto LOAD CSV WITH HEADERS FROM 'file:///product_category_name_translation.csv' AS row
CALL {
  WITH row
  MERGE (cat:Category {name: row.product_category_name})
  ON CREATE SET
    cat.name_english = row.product_category_name_english
} IN TRANSACTIONS OF 500 ROWS;

// ===== ÉTAPE 6: CHARGEMENT DES CLIENTS =====
:auto LOAD CSV WITH HEADERS FROM 'file:///customers.csv' AS row
CALL {
  WITH row
  MERGE (c:Customer {customer_id: row.customer_id})
  ON CREATE SET
    c.customer_unique_id = row.customer_unique_id,
    c.zip_code_prefix = row.customer_zip_code_prefix,
    c.city = row.customer_city,
    c.state = row.customer_state
} IN TRANSACTIONS OF 500 ROWS;

// ===== ÉTAPE 7: CHARGEMENT DES VENDEURS =====
:auto LOAD CSV WITH HEADERS FROM 'file:///sellers.csv' AS row
CALL {
  WITH row
  MERGE (s:Seller {seller_id: row.seller_id})
  ON CREATE SET
    s.zip_code_prefix = row.seller_zip_code_prefix,
    s.city = row.seller_city,
    s.state = row.seller_state
} IN TRANSACTIONS OF 500 ROWS;

// ===== ÉTAPE 8: CHARGEMENT DES PRODUITS =====
:auto LOAD CSV WITH HEADERS FROM 'file:///products.csv' AS row
CALL {
  WITH row
  MERGE (p:Product {product_id: row.product_id})
  ON CREATE SET
    p.category_name = row.product_category_name,
    p.name_length = toInteger(row.product_name_lenght),
    p.description_length = toInteger(row.product_description_lenght),
    p.photos_qty = toInteger(row.product_photos_qty),
    p.weight_g = toFloat(row.product_weight_g),
    p.length_cm = toFloat(row.product_length_cm),
    p.height_cm = toFloat(row.product_height_cm),
    p.width_cm = toFloat(row.product_width_cm)
} IN TRANSACTIONS OF 500 ROWS;

// ===== ÉTAPE 9: CHARGEMENT DES LEADS QUALIFIÉS =====
:auto LOAD CSV WITH HEADERS FROM 'file:///leads_qualified.csv' AS row
CALL {
  WITH row
  MERGE (ql:QualifiedLead {mql_id: row.mql_id})
  ON CREATE SET
    ql.first_contact_date = CASE WHEN row.first_contact_date IS NOT NULL AND row.first_contact_date <> ''
                            THEN datetime(
                              CASE 
                                WHEN row.first_contact_date CONTAINS ' ' 
                                THEN replace(row.first_contact_date, ' ', 'T') + ':00'
                                ELSE row.first_contact_date + 'T00:00:00'
                              END
                            ) ELSE null END,
    ql.landing_page_id = row.landing_page_id,
    ql.origin = row.origin
} IN TRANSACTIONS OF 500 ROWS;

// ===== ÉTAPE 10: CHARGEMENT DES LEADS CONVERTIS =====
:auto LOAD CSV WITH HEADERS FROM 'file:///leads_closed.csv' AS row
CALL {
  WITH row
  MERGE (cl:ClosedLead {mql_id: row.mql_id})
  ON CREATE SET
    cl.seller_id = row.seller_id,
    cl.sdr_id = row.sdr_id,
    cl.sr_id = row.sr_id,
    cl.won_date = CASE WHEN row.won_date IS NOT NULL AND row.won_date <> ''
                  THEN datetime(
                    CASE 
                      WHEN row.won_date CONTAINS ' ' 
                      THEN replace(row.won_date, ' ', 'T') + ':00'
                      ELSE row.won_date + 'T00:00:00'
                    END
                  ) ELSE null END,
    cl.business_segment = row.business_segment,
    cl.lead_type = row.lead_type,
    cl.lead_behaviour_profile = row.lead_behaviour_profile,
    cl.has_company = CASE WHEN row.has_company IN ['True', '1', 'true'] THEN true
                          WHEN row.has_company IN ['False', '0', 'false'] THEN false
                          ELSE null END,
    cl.has_gtin = CASE WHEN row.has_gtin IN ['True', '1', 'true'] THEN true
                       WHEN row.has_gtin IN ['False', '0', 'false'] THEN false
                       ELSE null END,
    cl.average_stock = row.average_stock,
    cl.business_type = row.business_type,
    cl.declared_product_catalog_size = CASE WHEN row.declared_product_catalog_size IS NOT NULL AND row.declared_product_catalog_size <> ''
                                       THEN toFloat(row.declared_product_catalog_size) ELSE null END,
    cl.declared_monthly_revenue = CASE WHEN row.declared_monthly_revenue IS NOT NULL AND row.declared_monthly_revenue <> ''
                                  THEN toFloat(row.declared_monthly_revenue) ELSE null END
} IN TRANSACTIONS OF 500 ROWS;

// ===== ÉTAPE 11: CHARGEMENT DES COMMANDES =====
:auto LOAD CSV WITH HEADERS FROM 'file:///orders.csv' AS row
CALL {
  WITH row
  MERGE (o:Order {order_id: row.order_id})
  ON CREATE SET
    o.customer_id = row.customer_id,
    o.status = row.order_status,
    o.purchase_timestamp = CASE WHEN row.order_purchase_timestamp IS NOT NULL AND row.order_purchase_timestamp <> ''
                            THEN datetime(
                              CASE 
                                WHEN row.order_purchase_timestamp CONTAINS ' ' 
                                THEN replace(row.order_purchase_timestamp, ' ', 'T') + ':00'
                                ELSE row.order_purchase_timestamp + 'T00:00:00'
                              END
                            ) ELSE null END,
    o.approved_at = CASE WHEN row.order_approved_at IS NOT NULL AND row.order_approved_at <> ''
                     THEN datetime(
                       CASE 
                         WHEN row.order_approved_at CONTAINS ' ' 
                         THEN replace(row.order_approved_at, ' ', 'T') + ':00'
                         ELSE row.order_approved_at + 'T00:00:00'
                       END
                     ) ELSE null END,
    o.delivered_carrier_date = CASE WHEN row.order_delivered_carrier_date IS NOT NULL AND row.order_delivered_carrier_date <> ''
                                THEN datetime(
                                  CASE 
                                    WHEN row.order_delivered_carrier_date CONTAINS ' ' 
                                    THEN replace(row.order_delivered_carrier_date, ' ', 'T') + ':00'
                                    ELSE row.order_delivered_carrier_date + 'T00:00:00'
                                  END
                                ) ELSE null END,
    o.delivered_customer_date = CASE WHEN row.order_delivered_customer_date IS NOT NULL AND row.order_delivered_customer_date <> ''
                                 THEN datetime(
                                   CASE 
                                     WHEN row.order_delivered_customer_date CONTAINS ' ' 
                                     THEN replace(row.order_delivered_customer_date, ' ', 'T') + ':00'
                                     ELSE row.order_delivered_customer_date + 'T00:00:00'
                                   END
                                 ) ELSE null END,
    o.estimated_delivery_date = CASE WHEN row.order_estimated_delivery_date IS NOT NULL AND row.order_estimated_delivery_date <> ''
                                 THEN datetime(
                                   CASE 
                                     WHEN row.order_estimated_delivery_date CONTAINS ' ' 
                                     THEN replace(row.order_estimated_delivery_date, ' ', 'T') + ':00'
                                     ELSE row.order_estimated_delivery_date + 'T00:00:00'
                                   END
                                 ) ELSE null END
} IN TRANSACTIONS OF 500 ROWS;

// ===== ÉTAPE 12: CHARGEMENT DES ARTICLES DE COMMANDE =====
:auto LOAD CSV WITH HEADERS FROM 'file:///order_items.csv' AS row
CALL {
  WITH row
  MERGE (oi:OrderItem {order_item_id: row.order_item_id})
  ON CREATE SET
    oi.order_id = row.order_id,
    oi.product_id = row.product_id,
    oi.seller_id = row.seller_id,
    oi.shipping_limit_date = CASE WHEN row.shipping_limit_date IS NOT NULL AND row.shipping_limit_date <> ''
                             THEN datetime(
                               CASE 
                                 WHEN row.shipping_limit_date CONTAINS ' ' 
                                 THEN replace(row.shipping_limit_date, ' ', 'T') + ':00'
                                 ELSE row.shipping_limit_date + 'T00:00:00'
                               END
                             ) ELSE null END,
    oi.price = toFloat(row.price),
    oi.freight_value = toFloat(row.freight_value)
} IN TRANSACTIONS OF 500 ROWS;

// ===== ÉTAPE 13: CHARGEMENT DES PAIEMENTS =====
:auto LOAD CSV WITH HEADERS FROM 'file:///order_payments.csv' AS row
CALL {
  WITH row
  MERGE (pay:Payment {
    order_id: row.order_id,
    payment_sequential: toInteger(row.payment_sequential)
  })
  ON CREATE SET
    pay.payment_type = row.payment_type,
    pay.installments = toInteger(row.payment_installments),
    pay.payment_value = toFloat(row.payment_value)
} IN TRANSACTIONS OF 500 ROWS;

// ===== ÉTAPE 14: CHARGEMENT DES AVIS =====
// Note: Si erreurs de parsing, nettoyez d'abord le CSV avec le script Python fourni
:auto LOAD CSV WITH HEADERS FROM 'file:///order_reviews.csv' AS row
WITH row WHERE row.review_id IS NOT NULL
CALL {
  WITH row
  MERGE (r:Review {review_id: row.review_id})
  ON CREATE SET
    r.order_id = row.order_id,
    r.score = CASE WHEN row.review_score IS NOT NULL 
                   THEN toInteger(row.review_score) ELSE null END,
    r.comment_title = CASE WHEN row.review_comment_title IS NOT NULL 
                           THEN substring(row.review_comment_title, 0, 1000) ELSE null END,
    r.comment_message = CASE WHEN row.review_comment_message IS NOT NULL 
                             THEN substring(row.review_comment_message, 0, 5000) ELSE null END,
    r.creation_date = CASE WHEN row.review_creation_date IS NOT NULL AND row.review_creation_date <> ''
                       THEN datetime(
                         CASE 
                           WHEN row.review_creation_date CONTAINS ' ' 
                           THEN replace(row.review_creation_date, ' ', 'T') + ':00'
                           ELSE row.review_creation_date + 'T00:00:00'
                         END
                       ) ELSE null END,
    r.answer_timestamp = CASE WHEN row.review_answer_timestamp IS NOT NULL AND row.review_answer_timestamp <> ''
                          THEN datetime(
                            CASE 
                              WHEN row.review_answer_timestamp CONTAINS ' ' 
                              THEN replace(row.review_answer_timestamp, ' ', 'T') + ':00'
                              ELSE row.review_answer_timestamp + 'T00:00:00'
                            END
                          ) ELSE null END
} IN TRANSACTIONS OF 500 ROWS;

// ===== ÉTAPE 15: RELATIONS - GÉOLOCALISATION =====
// Clients -> Géolocalisation
:auto CALL {
  MATCH (c:Customer)
  WHERE c.zip_code_prefix IS NOT NULL
    AND NOT EXISTS((c)-[:LIVES_IN]->())
  WITH c
  MATCH (g:Geolocation)
  WHERE c.zip_code_prefix = g.zip_code_prefix
  MERGE (c)-[:LIVES_IN]->(g)
} IN TRANSACTIONS OF 1000 ROWS;

// Vendeurs -> Géolocalisation
:auto CALL {
  MATCH (s:Seller)
  WHERE s.zip_code_prefix IS NOT NULL
    AND NOT EXISTS((s)-[:LOCATED_IN]->())
  WITH s
  MATCH (g:Geolocation)
  WHERE s.zip_code_prefix = g.zip_code_prefix
  MERGE (s)-[:LOCATED_IN]->(g)
} IN TRANSACTIONS OF 1000 ROWS;

// ===== ÉTAPE 16: RELATIONS - PRODUITS =====
:auto CALL {
  MATCH (p:Product)
  WHERE p.category_name IS NOT NULL
    AND NOT EXISTS((p)-[:BELONGS_TO]->())
  WITH p
  MATCH (cat:Category)
  WHERE p.category_name = cat.name
  MERGE (p)-[:BELONGS_TO]->(cat)
} IN TRANSACTIONS OF 1000 ROWS;

// ===== ÉTAPE 17: RELATIONS - COMMANDES =====
// Clients -> Commandes
:auto CALL {
  MATCH (o:Order)
  WHERE o.customer_id IS NOT NULL
    AND NOT EXISTS(()-[:PLACED]->(o))
  WITH o
  MATCH (c:Customer)
  WHERE c.customer_id = o.customer_id
  MERGE (c)-[:PLACED]->(o)
} IN TRANSACTIONS OF 1000 ROWS;

// Commandes -> Articles
:auto CALL {
  MATCH (oi:OrderItem)
  WHERE oi.order_id IS NOT NULL
    AND NOT EXISTS(()-[:CONTAINS]->(oi))
  WITH oi
  MATCH (o:Order)
  WHERE o.order_id = oi.order_id
  MERGE (o)-[:CONTAINS]->(oi)
} IN TRANSACTIONS OF 1000 ROWS;

// Articles -> Produits
:auto CALL {
  MATCH (oi:OrderItem)
  WHERE oi.product_id IS NOT NULL
    AND NOT EXISTS((oi)-[:OF_PRODUCT]->())
  WITH oi
  MATCH (p:Product)
  WHERE oi.product_id = p.product_id
  MERGE (oi)-[:OF_PRODUCT]->(p)
} IN TRANSACTIONS OF 1000 ROWS;

// Vendeurs -> Articles
:auto CALL {
  MATCH (oi:OrderItem)
  WHERE oi.seller_id IS NOT NULL
    AND NOT EXISTS(()-[:SOLD]->(oi))
  WITH oi
  MATCH (s:Seller)
  WHERE s.seller_id = oi.seller_id
  MERGE (s)-[:SOLD]->(oi)
} IN TRANSACTIONS OF 1000 ROWS;

// ===== ÉTAPE 18: RELATIONS - PAIEMENTS =====
:auto CALL {
  MATCH (pay:Payment)
  WHERE pay.order_id IS NOT NULL
    AND NOT EXISTS(()-[:PAID_BY]->(pay))
  WITH pay
  MATCH (o:Order)
  WHERE o.order_id = pay.order_id
  MERGE (o)-[:PAID_BY]->(pay)
} IN TRANSACTIONS OF 1000 ROWS;

// ===== ÉTAPE 19: RELATIONS - AVIS =====
// Avis -> Commandes
:auto CALL {
  MATCH (r:Review)
  WHERE r.order_id IS NOT NULL
    AND NOT EXISTS((r)-[:FOR_ORDER]->())
  WITH r
  MATCH (o:Order)
  WHERE r.order_id = o.order_id
  MERGE (r)-[:FOR_ORDER]->(o)
} IN TRANSACTIONS OF 1000 ROWS;

// Clients -> Avis
:auto CALL {
  MATCH (c:Customer)-[:PLACED]->(o:Order)<-[:FOR_ORDER]-(r:Review)
  WHERE NOT EXISTS((c)-[:WROTE]->(r))
  WITH c, r
  MERGE (c)-[:WROTE]->(r)
} IN TRANSACTIONS OF 1000 ROWS;

// Avis -> Produits
:auto CALL {
  MATCH (r:Review)-[:FOR_ORDER]->(o:Order)-[:CONTAINS]->(oi:OrderItem)-[:OF_PRODUCT]->(p:Product)
  WHERE NOT EXISTS((r)-[:ABOUT]->(p))
  WITH r, p
  MERGE (r)-[:ABOUT]->(p)
} IN TRANSACTIONS OF 1000 ROWS;

// ===== ÉTAPE 20: RELATIONS - LEADS =====
// Leads qualifiés -> Leads convertis
:auto CALL {
  MATCH (ql:QualifiedLead)
  WHERE NOT EXISTS((ql)-[:CONVERTED_TO]->())
  WITH ql
  MATCH (cl:ClosedLead)
  WHERE ql.mql_id = cl.mql_id
  MERGE (ql)-[:CONVERTED_TO]->(cl)
} IN TRANSACTIONS OF 1000 ROWS;

// Leads convertis -> Vendeurs
:auto CALL {
  MATCH (cl:ClosedLead)
  WHERE cl.seller_id IS NOT NULL
    AND NOT EXISTS((cl)-[:BECAME]->())
  WITH cl
  MATCH (s:Seller)
  WHERE cl.seller_id = s.seller_id
  MERGE (cl)-[:BECAME]->(s)
} IN TRANSACTIONS OF 1000 ROWS;

// ===== ÉTAPE 21: NETTOYAGE DES PROPRIÉTÉS REDONDANTES =====
:auto CALL {
  MATCH (o:Order) 
  WHERE o.customer_id IS NOT NULL 
  WITH o
  REMOVE o.customer_id
} IN TRANSACTIONS OF 1000 ROWS;

:auto CALL {
  MATCH (oi:OrderItem) 
  WHERE oi.order_id IS NOT NULL 
  WITH oi
  REMOVE oi.order_id
} IN TRANSACTIONS OF 1000 ROWS;

:auto CALL {
  MATCH (oi:OrderItem) 
  WHERE oi.product_id IS NOT NULL 
  WITH oi
  REMOVE oi.product_id
} IN TRANSACTIONS OF 1000 ROWS;

:auto CALL {
  MATCH (oi:OrderItem) 
  WHERE oi.seller_id IS NOT NULL 
  WITH oi
  REMOVE oi.seller_id
} IN TRANSACTIONS OF 1000 ROWS;

:auto CALL {
  MATCH (pay:Payment) 
  WHERE pay.order_id IS NOT NULL 
  WITH pay
  REMOVE pay.order_id
} IN TRANSACTIONS OF 1000 ROWS;

:auto CALL {
  MATCH (r:Review) 
  WHERE r.order_id IS NOT NULL 
  WITH r
  REMOVE r.order_id
} IN TRANSACTIONS OF 1000 ROWS;

:auto CALL {
  MATCH (cl:ClosedLead) 
  WHERE cl.seller_id IS NOT NULL 
  WITH cl
  REMOVE cl.seller_id
} IN TRANSACTIONS OF 1000 ROWS;

:auto CALL {
  MATCH (p:Product) 
  WHERE p.category_name IS NOT NULL 
  WITH p
  REMOVE p.category_name
} IN TRANSACTIONS OF 1000 ROWS;

// ===== ÉTAPE 22: VÉRIFICATION =====
MATCH (n)
RETURN labels(n)[0] as node_type, COUNT(n) as count
ORDER BY count DESC;

MATCH ()-[r]->()
RETURN type(r) as relationship_type, COUNT(r) as count
ORDER BY count DESC;
