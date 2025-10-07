import os
# Fichier spécifique à traiter 
csv_file = "order_reviews.csv"
# Vérifier que le fichier existe 
if not os.path.exists(csv_file):
    print(f"Erreur : {csv_file} introuvable dans ce dossier")     
    exit() 
print(f"Traitement : {csv_file}")
# Lire 
with open(csv_file, 'r', encoding='utf-8', errors='replace') as f:     
    content = f.read()
# Compter et corriger 
count = content.count(':\\')
if count > 0:
    content = content.replace(':\\', ':')
    
    # Sauvegarder     
    with open(csv_file, 'w', encoding='utf-8') as f:
        f.write(content)     
    print(f"✓ {count} corrections effectuées") 
else:     
    print("- Aucune correction nécessaire")
print("Terminé - Vous pouvez maintenant charger les données dans Neo4j") 
