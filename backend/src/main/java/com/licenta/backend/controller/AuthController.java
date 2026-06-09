package com.licenta.backend.controller;

import com.licenta.backend.dto.AuthResponse;
import com.licenta.backend.dto.RegisterRequest;
import com.licenta.backend.entity.User;
import com.licenta.backend.repository.UserRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import com.licenta.backend.dto.LoginRequest;
import com.licenta.backend.security.JwtService;

import static org.springframework.http.HttpStatus.*;

@RestController
@RequestMapping("/auth")
public class AuthController {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;


    public AuthController(UserRepository userRepository, PasswordEncoder passwordEncoder, JwtService jwtService) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
    }


    @PostMapping("/register")
    public ResponseEntity<AuthResponse> register(@RequestBody RegisterRequest req) {
        if (req.email() == null || req.email().isBlank() || req.password() == null || req.password().isBlank()) {
            throw new ResponseStatusException(BAD_REQUEST, "Email and password are required");
        }

        String email = req.email().toLowerCase().trim();

        if (userRepository.existsByEmail(email)) {
            throw new ResponseStatusException(CONFLICT, "Email already used");
        }

        User u = new User(email, passwordEncoder.encode(req.password()));
        userRepository.save(u);

        String token = jwtService.generateToken(u.getEmail());
        return ResponseEntity.status(CREATED).body(new AuthResponse(token));
    }


    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@RequestBody LoginRequest req) {
        if (req.email() == null || req.email().isBlank() || req.password() == null || req.password().isBlank()) {
            throw new ResponseStatusException(BAD_REQUEST, "Email and password are required");
        }

        String email = req.email().toLowerCase().trim();

        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new ResponseStatusException(UNAUTHORIZED, "Invalid credentials"));

        boolean ok = passwordEncoder.matches(req.password(), user.getPasswordHash());
        if (!ok) {
            throw new ResponseStatusException(UNAUTHORIZED, "Invalid credentials");
        }

        String token = jwtService.generateToken(user.getEmail());
        return ResponseEntity.ok(new AuthResponse(token));
    }

}