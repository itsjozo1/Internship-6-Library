SELECT A.Name, A.Surname,
    CASE
        WHEN A.Gender = 'M' THEN 'MUŠKI'
        WHEN A.Gender = 'Ž' THEN 'ŽENSKI'
        WHEN A.Gender IS NULL THEN 'NEPOZNATO'
        ELSE 'OSTALO'
    END as "Gender",
    C.Name as "CountryName", C.AverageSalary
FROM Authors A
LEFT JOIN Countries C ON A.CountryID = C.CountryId;



SELECT B.Title, B.ReleaseDate,
    STRING_AGG(A.Surname || ', ' || LEFT(A.Name, 1) || '; ', '' ORDER BY BA.AuthorshipType) AS "Names of main authors"
FROM Books B
JOIN BookAuthors BA ON B.BookId = BA.BookId
JOIN Authors A ON BA.AuthorId = A.AuthorId
WHERE B.BookType = 'Znanstvena' AND BA.AuthorshipType = 'Glavni'
GROUP BY B.Title, B.ReleaseDate;



SELECT B.Title,
    CASE
        WHEN L.LoanDate IS NOT NULL THEN 'Posuđeno'
        ELSE NULL
    END AS "Loan in december of 2023."
FROM Books B
CROSS JOIN Copies C
LEFT JOIN LoansCopies LC ON C.CopyId = LC.CopyId
LEFT JOIN Loans L ON LC.LoanId = L.LoanId AND L.LoanDate >= '2023-12-01' AND L.LoanDate <= '2023-12-31'
WHERE B.BookId = C.BookId
GROUP BY B.Title, L.LoanDate;



SELECT L.LibraryId, L.Name,
    COUNT(*) AS "Number of copies"
FROM Libraries L
JOIN Copies C ON L.LibraryId = C.LibraryId
GROUP BY L.LibraryId, L.Name
ORDER BY COUNT(*) DESC
LIMIT 3;



SELECT B.Title,
    COUNT(DISTINCT U.UserId) AS "Number of readers"
FROM Books B
JOIN Copies C ON B.BookId = C.BookId
JOIN LoansCopies LC ON C.CopyId = LC.CopyId
JOIN Loans L ON LC.LoanId = L.LoanId
JOIN Users U ON L.UserId = U.UserId
GROUP BY B.Title;



SELECT DISTINCT U.Name,U.Surname
FROM Users U
JOIN Loans L ON U.UserId = L.UserId
WHERE L.ReturnedDate IS NULL;



SELECT DISTINCT
    A.AuthorId,
    A.Name,
    A.Surname
FROM Authors A
JOIN BookAuthors BA ON A.AuthorId = BA.AuthorId
JOIN Books B ON BA.BookId = B.BookId
WHERE B.ReleaseDate BETWEEN '2019-01-01' AND '2022-12-31';



SELECT
    C.Name AS "Country name",
    COUNT(DISTINCT B.BookId) AS "Number of arts books"
FROM Books B
JOIN BookAuthors BA ON B.BookId = BA.BookId
JOIN Authors A ON BA.AuthorId = A.AuthorId
JOIN Countries C ON A.CountryID = C.CountryId
WHERE
    B.BookType = 'Umjetnička'
GROUP BY C.Name
ORDER BY COUNT(DISTINCT A.AuthorId) DESC;




SELECT A.AuthorId, A.Name, A.Surname,
    COALESCE(B.BookType, 'Nepoznato') AS "Book genre",
    COUNT(LC.CopyId) AS "Number of loans"
FROM Authors A
CROSS JOIN (SELECT DISTINCT BookType FROM Books) B

LEFT JOIN BookAuthors BA ON A.AuthorId = BA.AuthorId
LEFT JOIN Books BK ON BA.BookId = BK.BookId AND BK.BookType = B.BookType
LEFT JOIN Copies C ON BK.BookId = C.BookId
LEFT JOIN LoansCopies LC ON C.CopyId = LC.CopyId
GROUP BY A.AuthorId, A.Name, A.Surname, B.BookType
ORDER BY A.AuthorId, "Number of loans" DESC;



SELECT U.UserId, U.Name, U.Surname,
    CASE
        WHEN SUM(CalculateFee(L.LoanId)) IS NULL THEN 'ČISTO'
        ELSE CAST(SUM(CalculateFee(L.LoanId)) AS VARCHAR) || 'e'
    END AS "Loan fee status"
FROM Users U
LEFT JOIN Loans L ON U.UserId = L.UserId AND L.ReturnedDate IS NULL
GROUP BY U.UserId, U.Name, U.Surname;



SELECT A.AuthorId, A.Name, A.Surname, B.Title AS "First released book"
FROM Authors A
LEFT JOIN (
    SELECT
        BA.AuthorId,
        MIN(B.ReleaseDate) AS FirstReleaseDate
    FROM BookAuthors BA
    LEFT JOIN Books B ON BA.BookId = B.BookId
    GROUP BY BA.AuthorId
) FirstBook ON A.AuthorId = FirstBook.AuthorId
LEFT JOIN Books B ON FirstBook.FirstReleaseDate = B.ReleaseDate
LEFT JOIN BookAuthors BA ON A.AuthorId = BA.AuthorId AND B.BookId = BA.BookId;




SELECT A.CountryID, C.Name, B2.Title AS "Second released book"
FROM Authors A
LEFT JOIN Countries C ON A.CountryID = C.CountryId
LEFT JOIN (
    SELECT
        BA.AuthorId,
        LEAD(B.ReleaseDate) OVER (PARTITION BY BA.AuthorId ORDER BY B.ReleaseDate) AS SecondReleaseDate,
        B.BookId
    FROM
        BookAuthors BA
    LEFT JOIN Books B ON BA.BookId = B.BookId
) SecondBook ON A.AuthorId = SecondBook.AuthorId
LEFT JOIN Books B2 ON A.AuthorId = SecondBook.AuthorId AND B2.ReleaseDate = SecondBook.SecondReleaseDate
LEFT JOIN BookAuthors BA2 ON A.AuthorId = BA2.AuthorId AND B2.BookId = BA2.BookId;


--SELECT B.BookId, B.Title, COUNT(LC.LoanId) AS "Active loans of copies"
--FROM Books B
--LEFT JOIN Copies C ON B.BookId = C.BookId
--LEFT JOIN LoansCopies LC ON C.CopyId = LC.CopyId
--LEFT JOIN Loans L ON LC.LoanId = L.LoanId
--WHERE L.ReturnedDate IS NULL
--GROUP BY B.BookId, B.Title
--HAVING COUNT(LC.LoanId) >= 10;


SELECT C.CountryId,
    COALESCE(C.Name, 'Nepoznato'),
    ROUND(AVG(loans_per_copy), 2) AS "Average loans per copy"
FROM (
    SELECT
        COALESCE(A.CountryID, 0) AS CountryId,
        COUNT(LC.CopyId) * 1.0 / COUNT(DISTINCT LC.CopyId) AS loans_per_copy
    FROM LoansCopies LC
    LEFT JOIN Copies CP ON LC.CopyId = CP.CopyId
    LEFT JOIN Books B ON CP.BookId = B.BookId
    LEFT JOIN Authors A ON B.BookId = A.AuthorId
    GROUP BY A.CountryID, B.BookId
) AS AvgLoansPerCopy
LEFT JOIN Countries C ON AvgLoansPerCopy.CountryId = C.CountryId
GROUP BY C.CountryId, C.Name;



SELECT A.AuthorId, A.Name, A.Surname,
    ROUND(SUM(SQRT(CAST(CP.TotalCopies AS NUMERIC) / BA.NumAuthors)), 2) AS "Wealth (€)"
FROM Authors A
JOIN (
    SELECT
        BA.BookId,
        COUNT(*) AS NumAuthors
    FROM BookAuthors BA
    GROUP BY BA.BookId
) BA ON A.AuthorId IN (SELECT BA2.AuthorId FROM BookAuthors BA2 WHERE BA2.BookId = BA.BookId)
JOIN (
    SELECT C.BookId, COUNT(*) AS TotalCopies
    FROM Copies C
    GROUP BY C.BookId
) CP ON BA.BookId = CP.BookId
GROUP BY A.AuthorId, A.Name, A.Surname
ORDER BY "Wealth (€)" DESC
LIMIT 10;
