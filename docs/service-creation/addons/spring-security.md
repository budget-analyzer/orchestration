# Add-On: Spring Security

## Purpose
Authentication and authorization for REST API microservices using Spring Security. Provides
JWT-based stateless authentication, role-based access control, and method-level security.

## Use Cases
- JWT-based authentication for stateless microservices
- Role-based access control (RBAC)
- Method-level security with annotations
- API endpoint protection
- Integration with centralized authentication service
- OAuth2 resource server configuration
- Public vs protected endpoints

## Benefits
- **Industry Standard**: Battle-tested security framework
- **Flexible Configuration**: Fine-grained control over security policies
- **Stateless Authentication**: JWT tokens for scalable microservices
- **Method Security**: Protect individual methods with annotations
- **Spring Integration**: Native Spring Boot auto-configuration
- **OAuth2 Support**: Integration with OAuth2 providers
- **CORS Handling**: Built-in CORS configuration

## Architecture

```
┌─────────────────┐
│  Client         │
│  (Web/Mobile)   │
└────────┬────────┘
         │ 1. Login Request (username/password)
         ▼
┌─────────────────────────┐
│  Authentication Service │  (Separate service - not covered here)
│  Issues JWT Token       │
└────────┬────────────────┘
         │ 2. JWT Token
         ▼
┌─────────────────────────┐
│  Client stores token    │
└────────┬────────────────┘
         │ 3. API Request + JWT in Authorization header
         ▼
┌─────────────────────────────────┐
│  {SERVICE_NAME}                 │
│  ┌──────────────────────────┐   │
│  │ Security Filter Chain    │   │
│  │ - JWT Validation         │   │
│  │ - Extract Claims         │   │
│  │ - Set Authentication     │   │
│  └──────────────────────────┘   │
│  ┌──────────────────────────┐   │
│  │ Protected Controller     │   │
│  │ @PreAuthorize("ROLE_*")  │   │
│  └──────────────────────────┘   │
└─────────────────────────────────┘
```

## Dependencies

### Step 1: Add to `gradle/libs.versions.toml`

```toml
[versions]
jjwt = "0.12.6"

[libraries]
# Add to existing libraries section
spring-boot-starter-security = { module = "org.springframework.boot:spring-boot-starter-security" }

# JWT libraries
jjwt-api = { module = "io.jsonwebtoken:jjwt-api", version.ref = "jjwt" }
jjwt-impl = { module = "io.jsonwebtoken:jjwt-impl", version.ref = "jjwt" }
jjwt-jackson = { module = "io.jsonwebtoken:jjwt-jackson", version.ref = "jjwt" }

# Test
spring-security-test = { module = "org.springframework.security:spring-security-test" }
```

### Step 2: Add to `build.gradle.kts`

```kotlin
dependencies {
    // ... existing dependencies

    // Spring Security
    implementation(libs.spring.boot.starter.security)

    // JWT
    implementation(libs.jjwt.api)
    runtimeOnly(libs.jjwt.impl)
    runtimeOnly(libs.jjwt.jackson)

    // Test
    testImplementation(libs.spring.security.test)
}
```

## Configuration

### application.yml

```yaml
spring:
  application:
    name: {SERVICE_NAME}

  security:
    # JWT configuration
    jwt:
      secret: ${JWT_SECRET:your-secret-key-change-in-production-min-256-bits}
      expiration: ${JWT_EXPIRATION:86400000}  # 24 hours in milliseconds

budgetanalyzer:
  {SERVICE_NAME}:
    security:
      enabled: true
      # Public endpoints that don't require authentication
      public-endpoints:
        - /actuator/health
        - /actuator/info
        - /v3/api-docs/**
        - /swagger-ui/**
        - /swagger-ui.html
      # CORS configuration
      cors:
        allowed-origins:
          - http://localhost:3000
          - http://localhost:8080
        allowed-methods:
          - GET
          - POST
          - PUT
          - DELETE
          - PATCH
        allowed-headers:
          - "*"
        allow-credentials: true
        max-age: 3600
```

### Test Configuration (src/test/resources/application.yml)

```yaml
spring:
  security:
    jwt:
      secret: test-secret-key-for-unit-tests-minimum-256-bits-required

budgetanalyzer:
  {SERVICE_NAME}:
    security:
      enabled: false  # Disable security in tests by default
```

## Directory Structure

```
src/
└── main/
    └── java/org/budgetanalyzer/{DOMAIN_NAME}/
        ├── config/
        │   ├── SecurityConfig.java           # Main security configuration
        │   └── SecurityProperties.java       # Configuration properties
        ├── security/
        │   ├── JwtAuthenticationFilter.java  # JWT filter
        │   ├── JwtTokenProvider.java         # JWT utility
        │   └── UserPrincipal.java            # Custom UserDetails
        └── api/
            └── SecuredController.java        # Example secured controller
```

## Code Examples

### Security Properties

Create `src/main/java/org/budgetanalyzer/{DOMAIN_NAME}/config/SecurityProperties.java`:

```java
package org.budgetanalyzer.{DOMAIN_NAME}.config;

import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@ConfigurationProperties(prefix = "budgetanalyzer.{SERVICE_NAME}.security")
public class SecurityProperties {
  private boolean enabled = true;
  private List<String> publicEndpoints = List.of();
  private CorsConfig cors = new CorsConfig();

  // Getters and setters
  public boolean isEnabled() {
    return enabled;
  }

  public void setEnabled(boolean enabled) {
    this.enabled = enabled;
  }

  public List<String> getPublicEndpoints() {
    return publicEndpoints;
  }

  public void setPublicEndpoints(List<String> publicEndpoints) {
    this.publicEndpoints = publicEndpoints;
  }

  public CorsConfig getCors() {
    return cors;
  }

  public void setCors(CorsConfig cors) {
    this.cors = cors;
  }

  public static class CorsConfig {
    private List<String> allowedOrigins = List.of("*");
    private List<String> allowedMethods = List.of("*");
    private List<String> allowedHeaders = List.of("*");
    private boolean allowCredentials = false;
    private long maxAge = 3600;

    // Getters and setters
    public List<String> getAllowedOrigins() {
      return allowedOrigins;
    }

    public void setAllowedOrigins(List<String> allowedOrigins) {
      this.allowedOrigins = allowedOrigins;
    }

    public List<String> getAllowedMethods() {
      return allowedMethods;
    }

    public void setAllowedMethods(List<String> allowedMethods) {
      this.allowedMethods = allowedMethods;
    }

    public List<String> getAllowedHeaders() {
      return allowedHeaders;
    }

    public void setAllowedHeaders(List<String> allowedHeaders) {
      this.allowedHeaders = allowedHeaders;
    }

    public boolean isAllowCredentials() {
      return allowCredentials;
    }

    public void setAllowCredentials(boolean allowCredentials) {
      this.allowCredentials = allowCredentials;
    }

    public long getMaxAge() {
      return maxAge;
    }

    public void setMaxAge(long maxAge) {
      this.maxAge = maxAge;
    }
  }
}
```

### JWT Token Provider

Create `src/main/java/org/budgetanalyzer/{DOMAIN_NAME}/security/JwtTokenProvider.java`:

```java
package org.budgetanalyzer.{DOMAIN_NAME}.security;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import java.util.Date;
import java.util.List;
import java.util.stream.Collectors;
import javax.crypto.SecretKey;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.stereotype.Component;

/**
 * Utility for creating and validating JWT tokens.
 */
@Component
public class JwtTokenProvider {
  private static final Logger log = LoggerFactory.getLogger(JwtTokenProvider.class);

  private final SecretKey secretKey;
  private final long jwtExpirationMs;

  public JwtTokenProvider(
      @Value("${spring.security.jwt.secret}") String secret,
      @Value("${spring.security.jwt.expiration}") long jwtExpirationMs) {
    this.secretKey = Keys.hmacShaKeyFor(secret.getBytes());
    this.jwtExpirationMs = jwtExpirationMs;
  }

  /**
   * Generate JWT token from authentication.
   */
  public String generateToken(Authentication authentication) {
    UserPrincipal userPrincipal = (UserPrincipal) authentication.getPrincipal();

    Date now = new Date();
    Date expiryDate = new Date(now.getTime() + jwtExpirationMs);

    List<String> roles = authentication.getAuthorities().stream()
        .map(GrantedAuthority::getAuthority)
        .collect(Collectors.toList());

    return Jwts.builder()
        .subject(userPrincipal.getUsername())
        .claim("userId", userPrincipal.getId())
        .claim("roles", roles)
        .issuedAt(now)
        .expiration(expiryDate)
        .signWith(secretKey)
        .compact();
  }

  /**
   * Extract username from JWT token.
   */
  public String getUsernameFromToken(String token) {
    Claims claims = Jwts.parser()
        .verifyWith(secretKey)
        .build()
        .parseSignedClaims(token)
        .getPayload();

    return claims.getSubject();
  }

  /**
   * Extract user ID from JWT token.
   */
  public Long getUserIdFromToken(String token) {
    Claims claims = Jwts.parser()
        .verifyWith(secretKey)
        .build()
        .parseSignedClaims(token)
        .getPayload();

    return claims.get("userId", Long.class);
  }

  /**
   * Extract roles from JWT token.
   */
  @SuppressWarnings("unchecked")
  public List<String> getRolesFromToken(String token) {
    Claims claims = Jwts.parser()
        .verifyWith(secretKey)
        .build()
        .parseSignedClaims(token)
        .getPayload();

    return claims.get("roles", List.class);
  }

  /**
   * Validate JWT token.
   */
  public boolean validateToken(String token) {
    try {
      Jwts.parser()
          .verifyWith(secretKey)
          .build()
          .parseSignedClaims(token);
      return true;
    } catch (SecurityException ex) {
      log.error("Invalid JWT signature");
    } catch (MalformedJwtException ex) {
      log.error("Invalid JWT token");
    } catch (ExpiredJwtException ex) {
      log.error("Expired JWT token");
    } catch (UnsupportedJwtException ex) {
      log.error("Unsupported JWT token");
    } catch (IllegalArgumentException ex) {
      log.error("JWT claims string is empty");
    }
    return false;
  }
}
```

### User Principal

Create `src/main/java/org/budgetanalyzer/{DOMAIN_NAME}/security/UserPrincipal.java`:

```java
package org.budgetanalyzer.{DOMAIN_NAME}.security;

import java.util.Collection;
import java.util.List;
import java.util.stream.Collectors;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

/**
 * Custom UserDetails implementation.
 * Represents authenticated user in security context.
 */
public class UserPrincipal implements UserDetails {
  private final Long id;
  private final String username;
  private final Collection<? extends GrantedAuthority> authorities;

  public UserPrincipal(Long id, String username, List<String> roles) {
    this.id = id;
    this.username = username;
    this.authorities = roles.stream()
        .map(role -> new SimpleGrantedAuthority("ROLE_" + role))
        .collect(Collectors.toList());
  }

  public Long getId() {
    return id;
  }

  @Override
  public String getUsername() {
    return username;
  }

  @Override
  public Collection<? extends GrantedAuthority> getAuthorities() {
    return authorities;
  }

  @Override
  public String getPassword() {
    return null;  // Not stored in JWT resource server
  }

  @Override
  public boolean isAccountNonExpired() {
    return true;
  }

  @Override
  public boolean isAccountNonLocked() {
    return true;
  }

  @Override
  public boolean isCredentialsNonExpired() {
    return true;
  }

  @Override
  public boolean isEnabled() {
    return true;
  }
}
```

### JWT Authentication Filter

Create `src/main/java/org/budgetanalyzer/{DOMAIN_NAME}/security/JwtAuthenticationFilter.java`:

```java
package org.budgetanalyzer.{DOMAIN_NAME}.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Filter to extract and validate JWT from request.
 * Sets authentication in SecurityContext if valid.
 */
public class JwtAuthenticationFilter extends OncePerRequestFilter {
  private static final Logger log = LoggerFactory.getLogger(JwtAuthenticationFilter.class);
  private static final String AUTHORIZATION_HEADER = "Authorization";
  private static final String BEARER_PREFIX = "Bearer ";

  private final JwtTokenProvider tokenProvider;

  public JwtAuthenticationFilter(JwtTokenProvider tokenProvider) {
    this.tokenProvider = tokenProvider;
  }

  @Override
  protected void doFilterInternal(
      HttpServletRequest request,
      HttpServletResponse response,
      FilterChain filterChain) throws ServletException, IOException {

    try {
      String jwt = getJwtFromRequest(request);

      if (StringUtils.hasText(jwt) && tokenProvider.validateToken(jwt)) {
        String username = tokenProvider.getUsernameFromToken(jwt);
        Long userId = tokenProvider.getUserIdFromToken(jwt);
        List<String> roles = tokenProvider.getRolesFromToken(jwt);

        UserPrincipal userPrincipal = new UserPrincipal(userId, username, roles);

        UsernamePasswordAuthenticationToken authentication =
            new UsernamePasswordAuthenticationToken(
                userPrincipal, null, userPrincipal.getAuthorities());
        authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));

        SecurityContextHolder.getContext().setAuthentication(authentication);
        log.debug("Set authentication for user: {}", username);
      }
    } catch (Exception ex) {
      log.error("Could not set user authentication in security context", ex);
    }

    filterChain.doFilter(request, response);
  }

  /**
   * Extract JWT token from Authorization header.
   */
  private String getJwtFromRequest(HttpServletRequest request) {
    String bearerToken = request.getHeader(AUTHORIZATION_HEADER);
    if (StringUtils.hasText(bearerToken) && bearerToken.startsWith(BEARER_PREFIX)) {
      return bearerToken.substring(BEARER_PREFIX.length());
    }
    return null;
  }
}
```

### Security Configuration

Create `src/main/java/org/budgetanalyzer/{DOMAIN_NAME}/config/SecurityConfig.java`:

```java
package org.budgetanalyzer.{DOMAIN_NAME}.config;

import org.budgetanalyzer.{DOMAIN_NAME}.security.JwtAuthenticationFilter;
import org.budgetanalyzer.{DOMAIN_NAME}.security.JwtTokenProvider;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

/**
 * Spring Security configuration for JWT-based authentication.
 */
@Configuration
@EnableWebSecurity
@EnableMethodSecurity  // Enable @PreAuthorize, @Secured, @RolesAllowed
@ConditionalOnProperty(
    value = "budgetanalyzer.{SERVICE_NAME}.security.enabled",
    havingValue = "true",
    matchIfMissing = true
)
public class SecurityConfig {

  private final SecurityProperties securityProperties;
  private final JwtTokenProvider tokenProvider;

  public SecurityConfig(SecurityProperties securityProperties, JwtTokenProvider tokenProvider) {
    this.securityProperties = securityProperties;
    this.tokenProvider = tokenProvider;
  }

  @Bean
  public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http
        // Disable CSRF (not needed for stateless JWT)
        .csrf(AbstractHttpConfigurer::disable)

        // Enable CORS
        .cors(cors -> cors.configurationSource(corsConfigurationSource()))

        // Stateless session (JWT is stateless)
        .sessionManagement(
            session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))

        // Authorization rules
        .authorizeHttpRequests(auth -> {
          // Public endpoints
          securityProperties.getPublicEndpoints().forEach(
              endpoint -> auth.requestMatchers(endpoint).permitAll()
          );

          // All other endpoints require authentication
          auth.anyRequest().authenticated();
        })

        // Add JWT filter
        .addFilterBefore(
            new JwtAuthenticationFilter(tokenProvider),
            UsernamePasswordAuthenticationFilter.class
        );

    return http.build();
  }

  /**
   * CORS configuration from properties.
   */
  @Bean
  public CorsConfigurationSource corsConfigurationSource() {
    CorsConfiguration configuration = new CorsConfiguration();
    configuration.setAllowedOrigins(securityProperties.getCors().getAllowedOrigins());
    configuration.setAllowedMethods(securityProperties.getCors().getAllowedMethods());
    configuration.setAllowedHeaders(securityProperties.getCors().getAllowedHeaders());
    configuration.setAllowCredentials(securityProperties.getCors().isAllowCredentials());
    configuration.setMaxAge(securityProperties.getCors().getMaxAge());

    UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/**", configuration);
    return source;
  }
}
```

### Secured Controller Example

```java
package org.budgetanalyzer.{DOMAIN_NAME}.api;

import org.budgetanalyzer.{DOMAIN_NAME}.security.UserPrincipal;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/secure")
public class SecuredController {

  /**
   * Accessible by any authenticated user.
   */
  @GetMapping("/user")
  public String userEndpoint(@AuthenticationPrincipal UserPrincipal user) {
    return "Hello, " + user.getUsername();
  }

  /**
   * Accessible only by users with ADMIN role.
   */
  @GetMapping("/admin")
  @PreAuthorize("hasRole('ADMIN')")
  public String adminEndpoint() {
    return "Admin access granted";
  }

  /**
   * Accessible by users with either USER or ADMIN role.
   */
  @GetMapping("/data")
  @PreAuthorize("hasAnyRole('USER', 'ADMIN')")
  public String dataEndpoint() {
    return "Data access granted";
  }

  /**
   * Method-level security with custom expression.
   */
  @DeleteMapping("/resource/{id}")
  @PreAuthorize("hasRole('ADMIN') or @resourceService.isOwner(#id, authentication.principal.id)")
  public void deleteResource(@PathVariable Long id) {
    // Delete logic
  }
}
```

## Testing

### Test with @WithMockUser

```java
package org.budgetanalyzer.{DOMAIN_NAME}.api;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(SecuredController.class)
class SecuredControllerTest {

  @Autowired
  private MockMvc mockMvc;

  @Test
  void shouldDenyAccessWithoutAuthentication() throws Exception {
    mockMvc.perform(get("/api/v1/secure/user"))
        .andExpect(status().isUnauthorized());
  }

  @Test
  @WithMockUser(username = "testuser", roles = {"USER"})
  void shouldAllowAccessWithAuthentication() throws Exception {
    mockMvc.perform(get("/api/v1/secure/user"))
        .andExpect(status().isOk())
        .andExpect(content().string("Hello, testuser"));
  }

  @Test
  @WithMockUser(username = "admin", roles = {"ADMIN"})
  void shouldAllowAdminAccess() throws Exception {
    mockMvc.perform(get("/api/v1/secure/admin"))
        .andExpect(status().isOk());
  }

  @Test
  @WithMockUser(username = "user", roles = {"USER"})
  void shouldDenyAdminAccessForRegularUser() throws Exception {
    mockMvc.perform(get("/api/v1/secure/admin"))
        .andExpect(status().isForbidden());
  }
}
```

### Test with Real JWT Token

```java
@Test
void shouldAuthenticateWithValidJwt() throws Exception {
  // Generate JWT token
  String token = generateTestToken("testuser", List.of("USER"));

  mockMvc.perform(get("/api/v1/secure/user")
          .header("Authorization", "Bearer " + token))
      .andExpect(status().isOk());
}

private String generateTestToken(String username, List<String> roles) {
  // Use JwtTokenProvider to generate test token
  // Implementation depends on your setup
}
```

## Best Practices

1. **Use Strong Secret Keys**: Minimum 256 bits for HMAC-SHA256
2. **Store Secrets Securely**: Use environment variables, never hardcode
3. **Set Reasonable Expiration**: 15-60 minutes for access tokens
4. **Implement Refresh Tokens**: For long-lived sessions
5. **Log Security Events**: Login attempts, authorization failures
6. **Use HTTPS**: Always use HTTPS in production
7. **Validate All Inputs**: Even for authenticated users
8. **Principle of Least Privilege**: Grant minimal required permissions
9. **Test Security**: Include security tests in CI/CD
10. **Keep Dependencies Updated**: Security patches are critical

## Common Pitfalls

1. **Weak Secret Key**: Too short, predictable, or hardcoded
2. **No Token Expiration**: Long-lived tokens are security risk
3. **Storing Passwords in JWT**: Never put sensitive data in JWT
4. **Not Validating Token Signature**: Always verify signature
5. **Forgetting CORS**: Frontend can't access API
6. **Using GET for Sensitive Operations**: Use POST/PUT/DELETE
7. **Not Testing Authorization**: Only testing authentication

## Production Checklist

- [ ] Use strong, random JWT secret (minimum 256 bits)
- [ ] Store secret in environment variable or secrets manager
- [ ] Use HTTPS in production
- [ ] Set appropriate token expiration (15-60 minutes)
- [ ] Implement refresh token mechanism
- [ ] Configure CORS for production domains
- [ ] Enable security headers (CSP, X-Frame-Options, etc.)
- [ ] Log security events (login, authorization failures)
- [ ] Monitor for unusual patterns (brute force, etc.)
- [ ] Regular security audits and dependency updates

## Official Documentation

- [Spring Security](https://spring.io/projects/spring-security)
- [Spring Security Reference](https://docs.spring.io/spring-security/reference/index.html)
- [JWT.io](https://jwt.io/)
- [JJWT Library](https://github.com/jwtk/jjwt)
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)

## Related Add-Ons

- **redis.md**: Session storage for refresh tokens
- **testcontainers.md**: Integration testing with security enabled
- **springdoc-openapi.md**: Document secured endpoints in Swagger
