# Chapter 24: SOAP—Enterprise Web Services

## When RPC Met XML and HTTP

---

> *"SOAP: proof that even good intentions can lead to complex specifications."*
> — Web developers, circa 2010

---

## The Frustration

It's the late 1990s. The internet is mainstream. Businesses want their systems to communicate over the web, but:

- CORBA is complex and uses obscure ports blocked by firewalls
- RPC formats are binary and proprietary
- HTTP works everywhere, but there's no standard for services
- XML is the hot new universal data format

The question: can we build RPC over HTTP with XML?

## The World Before SOAP

Enterprise integration was painful:

```
System A (Windows/COM) ←→ [Custom bridge] ←→ System B (Unix/CORBA)
                        ←→ [Another bridge] ←→ System C (Java/RMI)

Every pair of systems needed a custom integration.
```

There was no universal web service standard.

## The Insight: XML + HTTP = Universal RPC

SOAP (originally Simple Object Access Protocol) combined:

- **XML** for message format (universal, text-based)
- **HTTP** for transport (firewall-friendly, ubiquitous)
- **WSDL** for service description
- **UDDI** for service discovery

```xml
POST /pricing HTTP/1.1
Content-Type: text/xml

<?xml version="1.0"?>
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope">
    <soap:Header>
        <auth:Token xmlns:auth="http://example.com/auth">
            abc123
        </auth:Token>
    </soap:Header>
    <soap:Body>
        <m:GetPrice xmlns:m="http://example.com/pricing">
            <m:ProductId>12345</m:ProductId>
        </m:GetPrice>
    </soap:Body>
</soap:Envelope>
```

It worked! Systems could finally communicate over standard web infrastructure.

## SOAP Architecture

### The Envelope

Every SOAP message has the same structure:

```xml
<soap:Envelope>
    <soap:Header>
        <!-- Optional: authentication, routing, transactions -->
    </soap:Header>
    <soap:Body>
        <!-- Required: the actual request or response -->
    </soap:Body>
</soap:Envelope>
```

### WSDL (Web Services Description Language)

Describes available operations:

```xml
<definitions name="PricingService">
    <types>
        <schema>
            <element name="GetPriceRequest">
                <complexType>
                    <sequence>
                        <element name="ProductId" type="string"/>
                    </sequence>
                </complexType>
            </element>
            <element name="GetPriceResponse">
                <complexType>
                    <sequence>
                        <element name="Price" type="decimal"/>
                    </sequence>
                </complexType>
            </element>
        </schema>
    </types>

    <message name="GetPriceInput">
        <part name="parameters" element="GetPriceRequest"/>
    </message>
    <message name="GetPriceOutput">
        <part name="parameters" element="GetPriceResponse"/>
    </message>

    <portType name="PricingPortType">
        <operation name="GetPrice">
            <input message="GetPriceInput"/>
            <output message="GetPriceOutput"/>
        </operation>
    </portType>

    <binding name="PricingBinding" type="PricingPortType">
        <!-- Protocol binding details -->
    </binding>

    <service name="PricingService">
        <port name="PricingPort" binding="PricingBinding">
            <soap:address location="http://example.com/pricing"/>
        </port>
    </service>
</definitions>
```

From this, tools generate client code:

```java
PricingService service = new PricingService();
PricingPort port = service.getPricingPort();
BigDecimal price = port.getPrice("12345");
```

### WS-* Standards

SOAP spawned a universe of specifications:

```
WS-Security      - Authentication, encryption, signatures
WS-ReliableMessaging - Guaranteed delivery
WS-Transaction   - Distributed transactions
WS-Addressing    - Message routing
WS-Policy        - Service constraints
WS-Federation    - Cross-domain identity
WS-Eventing      - Publish-subscribe
...and many more
```

Each solved a real problem. Together, they became "WS-Deathstar."

## Why SOAP Succeeded Initially

### Enterprise Needs
- Formal contracts (WSDL)
- Strong typing (XML Schema)
- Security standards (WS-Security)
- Transaction support
- Tooling (code generation)

### Firewall Friendly
HTTP over port 80 goes everywhere. CORBA's IIOP did not.

### Vendor Support
Microsoft, IBM, Oracle all invested heavily. Enterprise architects approved.

## Why SOAP Fell From Grace

### Verbosity

Simple call:
```xml
<?xml version="1.0"?>
<soap:Envelope
    xmlns:soap="http://www.w3.org/2003/05/soap-envelope"
    xmlns:m="http://example.com/pricing">
    <soap:Body>
        <m:GetPrice>
            <m:ProductId>12345</m:ProductId>
        </m:GetPrice>
    </soap:Body>
</soap:Envelope>
```

REST equivalent:
```
GET /products/12345/price
```

SOAP wraps everything in layers of XML.

### Complexity

Understanding the stack:

```
SOAP → WSDL → XML Schema → WS-Security → WS-Policy → ...

Each spec is hundreds of pages.
Interoperability testing became its own industry.
```

### Poor Fit for Web

```
SOAP: Everything is POST to one URL
HTTP: GET, POST, PUT, DELETE to many URLs

SOAP: Ignores HTTP caching, status codes, content types
HTTP: These are features, not overhead
```

SOAP ran *over* HTTP but ignored HTTP's design.

### The REST Revolution

Roy Fielding's dissertation showed HTTP already had an architecture. RESTful services emerged:

```
GET    /products/123     - Read a product
POST   /products         - Create a product
PUT    /products/123     - Update a product
DELETE /products/123     - Delete a product

No WSDL. No envelopes. Just HTTP.
```

By 2010, new APIs were REST. SOAP was for legacy.

## SOAP's Lasting Legacy

### The Good

- **Formal contracts**: WSDL showed the value of API descriptions (OpenAPI/Swagger inherited this)
- **Enterprise features**: Security, transactions, reliability—still needed
- **Tooling culture**: Code generation from specifications
- **Interoperability efforts**: WS-I organization worked on compatibility

### Where SOAP Remains

```
Enterprise systems    - Existing SOAP services run for decades
Financial services    - Regulations favor formal specifications
SOAP bridges          - Connect legacy systems
Healthcare (HL7 SOAP) - Standards-heavy industries
```

If you encounter SOAP, it's probably legacy.

## The Tradeoffs

| Decision | What We Got | What We Gave Up |
|----------|-------------|-----------------|
| XML format | Universal parsing | Verbosity |
| HTTP transport | Firewall-friendly | HTTP semantics wasted |
| WSDL contracts | Type safety, tooling | Flexibility |
| WS-* stack | Enterprise features | Complexity |

## The Principle

> **SOAP proved that web services could work. But it solved enterprise problems with enterprise complexity. When the web needed simpler APIs, REST—which embraced HTTP rather than tunneling through it—won.**

SOAP's lesson: don't add complexity for problems you don't have.

## When SOAP Might Still Make Sense

Rare, but possible:

**Legacy Integration**
```
Your system → SOAP → Partner's 15-year-old system
```

**Formal Contract Requirements**
```
Regulatory environment demanding WSDL contracts
```

**Transaction Coordination**
```
Distributed transactions across organizations (rare but exists)
```

For new APIs: use REST, GraphQL, or gRPC.

---

## Summary

- SOAP combined XML + HTTP for universal web services
- WSDL provided formal contract descriptions
- WS-* standards addressed enterprise needs (security, transactions)
- Verbosity and complexity led to decline
- REST's simplicity won for web APIs
- SOAP remains in enterprise legacy systems

---

*REST proved that embracing HTTP's design was better than ignoring it. Let's explore REST properly.*
