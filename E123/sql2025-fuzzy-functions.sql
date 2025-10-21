USE HellasGateV2
GO


-- Υπολογίζει τον αριθμό των αλλαγών που απαιτούνται για να μετατραπεί η μία συμβολοσειρά στην άλλη.
-- Η συνάρτηση επιστρέφει 1, γιατί χρειάζεται μόνο μία αλλαγή (π.χ. αφαίρεση του 's') για να μετατραπεί το 'Antonios' σε 'Antonio'.
SELECT EDIT_DISTANCE('Antonios', 'Antonio') AS Distance;

-- Επιστρέφει ποσοστό ομοιότητας (0–100) βασισμένο στην edit distance.
-- Αν η απόσταση είναι μικρή σε σχέση με το μήκος των λέξεων, η ομοιότητα θα είναι υψηλή, π.χ. ~90%.
SELECT EDIT_DISTANCE_SIMILARITY('Antonios', 'Antonio') AS Similarity;

-- Υπολογίζει την απόσταση μεταξύ δύο συμβολοσειρών με έμφαση στην αρχική τους ομοιότητα.
-- Η μέθοδος Jaro-Winkler δίνει μεγαλύτερη βαρύτητα στην αρχή της λέξης. Αν οι λέξεις ξεκινούν παρόμοια, η απόσταση είναι μικρή.
SELECT JARO_WINKLER_DISTANCE('Antonios', 'Antonio') AS JW_Distance;

-- Επιστρέφει ποσοστό ομοιότητας (0–100) με βάση Jaro-Winkler.
-- Αν οι λέξεις έχουν κοινή αρχή και παρόμοια δομή, η ομοιότητα θα είναι υψηλή, π.χ. ~98%.
SELECT JARO_WINKLER_SIMILARITY('Antonios', 'Antonio') AS JW_Similarity;

SELECT	a.custid, a.companyname, b.custid, b.companyname,
		EDIT_DISTANCE_SIMILARITY(a.companyname, b.companyname) as jw_similarity
FROM sales.Customers as a
JOIN sales.Customers as b on EDIT_DISTANCE_SIMILARITY(a.companyname, b.companyname) > 90
