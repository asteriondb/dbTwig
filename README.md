# DbTwig - An Ultra-Thin Middle-Tier Framework

**Comprised of a few hundred lines of JS/Express code and a PL/SQL package that's about 75 lines in length, DbTwig has to be the smallest, lightest fully functional middle-tier framework that will ever be.**

We know.  It seems crazy. But, when you build applications following patterns innovated by AsterionDB, that's all you need.  By utilizing DbTwig, you will embrace a software architecture that forces you to write secure applications and combats cybersecurity threats in ways that we have never imagined.

AsterionDB allows the Oracle database to seamlessly manage unstructured (e.g. file based) data. We migrate all of your digital assets out of the legacy file system and into the database. *(For those of you that think it's scary to store files in a database, remember, the file system is a database too.)* Given that they're now in the database, we don't need to keep a static filename anymore.

Think of it, if all of your files are now stored in the database and there are no more PDFs in your directories, how does ransomware infect your files?  They're not there anymore!

**DbTwig is our gift to the open-source community and society in general so that everyone can build applications that are inherently secure and resistant to cybersecurity attack. If this is intriguing to you, please continue reading.**

## DbTwig - The Basic Concept

So, its really pretty simple.  AsterionDB has pioneered the ability to merge all data types within the Oracle database.  That means structured and unstructured data are managed equally, side-by-side within the database.  A photograph, that you previously had to store outside of the RDBMS, is now just another data type that you manage and secure just like anything else.  This has profound security implications.

Naturally of course, if you have all of your data in the database, you're going to want all of your business logic there too.  As you might suspect, this also has very significant and profound implications.  

This is exactly the approach that is central to AsterionDB and the innovation that we bring to market.  DbTwig is a core technology that helps to make this all happen. DbTwig is technology you can use to gain the same level of efficiency and security that AsterionDB embodies.

By migrating all of your business logic down to the data layer you can implement an architecture that requires all API requests to proceed through audited, protected code.  Your business logic brokers all access to underlying data. There's no way to get at the data without going through the code. In a production environment, this is gold when it comes to security.

The Oracle database allows you to build a logical architecture that looks somewhat like a funnel - data at the top, logic below leading down to a singular access point - DbTwig. By leveraging JSON to convey our parameters and result data, we can create a choke point at the tip of the funnel.  This choke point is embodied by a sole function that delegates all valid API requests to logic further up the funnel.  That single choke point is DbTwig.

The DbTwig function looks at the JSON parameters and determines the appropriate logic to delegate to.  This is the technique that allows you to condense API access down to one function in a specific package.

Are you still with us? Good.  You've got all of your data in the database.  You've got all of your business logic in the database too.  Now, you'll have a single access point that all API requests are going to go through.  With that, you're going to revoke 'create session privilege' from your production application user and create a dedicated DbTwig user.  The DbTwig user will have no privileges other than the ability to connect the database and it will own a synonym - that's it.  The synonym will point to the DbTwig package within your application schema; that's the extent of the DbTwig user's universe, the DbTwig package.  That's all it can see. That's all it needs to see.

During production use, the only two accounts that can connect to the database are the DBA and the DbTwig user. Remember, the DbTwig user can't see anything.  All it gets to do is pass messages on from the middle-tier and return data from the database.  This is how we create a hyper-secure environment!!!  Now you can too.

## Pre-Requisite Knowledge

If you are an Oracle programmer, familiar with PL/SQL, you're going to be able to pick up this technology within minutes.  It is made for the way Oracle programmers work and think.

You'll also need to be familiar with JSON. If you're an Oracle programmer then you probably already know enough about JSON to get started. One skill you will need to acquire though is how JSON is integrated into the Oracle database. Oracle's JSON capabilities are very powerful. AsterionDB specifically leverages JSON in order to create a procedural interface for all data acquisition requests. In simple terms, we have PL/SQL functions that return JSON data - your data selected from the database.

By moving all of your select statements into a package in the database, you can turn off schema visibility in the middle-tier. That's the trick that allows you to implement a single access point through DbTwig for all middle-tier requests. This is also key to being able to build a hyper-secure architecture.

So...you've got PL/SQL at the data-layer. For the presentation layer, you get to use whatever you want!  All you have to do is send and receive JSON data to a RESTAPI (i.e. DbTwig).

## DbTwig - The AsterionDB Design Pattern


