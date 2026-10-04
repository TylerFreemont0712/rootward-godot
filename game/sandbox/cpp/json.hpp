// A small JSON reader and writer for the C++ spell harness (ADR-0046). The harness reads one JSON object on standard
// input and prints one JSON line per spell, as the Python and JavaScript harnesses do; cards never see this file.
//
// Numbers print the way JavaScript prints them (the shortest text that reads back as the same double, no ".0" on a
// whole number), so a C++ card's result compares equal to the other languages' in the worked examples.
#pragma once

#include <charconv>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <map>
#include <memory>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace rootward::json {

struct Value;
using Object = std::vector<std::pair<std::string, Value>>;
using Array = std::vector<Value>;

struct Value {
	enum class Kind { null, boolean, number, string, array, object };
	Kind kind = Kind::null;
	bool boolean = false;
	double number = 0;
	std::string text;
	std::shared_ptr<Array> items;
	std::shared_ptr<Object> fields;

	static Value of(double n) {
		Value v;
		v.kind = Kind::number;
		v.number = n;
		return v;
	}
	static Value of(bool b) {
		Value v;
		v.kind = Kind::boolean;
		v.boolean = b;
		return v;
	}
	static Value of(const std::string& s) {
		Value v;
		v.kind = Kind::string;
		v.text = s;
		return v;
	}
	static Value array() {
		Value v;
		v.kind = Kind::array;
		v.items = std::make_shared<Array>();
		return v;
	}
	static Value object() {
		Value v;
		v.kind = Kind::object;
		v.fields = std::make_shared<Object>();
		return v;
	}

	bool is_null() const { return kind == Kind::null; }
	bool is_number() const { return kind == Kind::number; }
	bool is_string() const { return kind == Kind::string; }
	bool is_array() const { return kind == Kind::array; }
	bool is_object() const { return kind == Kind::object; }

	// A field of an object, or null when it is missing (or this is not an object).
	const Value& operator[](const std::string& key) const {
		static const Value missing;
		if (!is_object()) return missing;
		for (const auto& [name, value] : *fields)
			if (name == key) return value;
		return missing;
	}
	bool has(const std::string& key) const { return !(*this)[key].is_null(); }
	const Array& list() const {
		static const Array empty;
		return is_array() ? *items : empty;
	}
	void push(Value v) { items->push_back(std::move(v)); }
	void set(const std::string& key, Value v) {
		for (auto& [name, value] : *fields)
			if (name == key) {
				value = std::move(v);
				return;
			}
		fields->emplace_back(key, std::move(v));
	}
	double num(double fallback = 0) const { return is_number() ? number : fallback; }
	std::string str(const std::string& fallback = "") const { return is_string() ? text : fallback; }
	bool truthy() const { return kind == Kind::boolean ? boolean : (is_number() ? number != 0 : false); }
};

class Parser {
public:
	explicit Parser(const std::string& source) : s(source) {}
	Value parse() {
		Value v = value();
		space();
		if (i != s.size()) fail("text after the end");
		return v;
	}

private:
	const std::string& s;
	size_t i = 0;

	[[noreturn]] void fail(const char* what) { throw std::runtime_error(std::string("bad JSON input: ") + what); }
	void space() {
		while (i < s.size() && (s[i] == ' ' || s[i] == '\n' || s[i] == '\r' || s[i] == '\t')) i++;
	}
	bool word(const char* w) {
		size_t n = std::char_traits<char>::length(w);
		if (s.compare(i, n, w) != 0) return false;
		i += n;
		return true;
	}
	Value value() {
		space();
		if (i >= s.size()) fail("unexpected end");
		char c = s[i];
		if (c == '{') return object();
		if (c == '[') return array();
		if (c == '"') return Value::of(string());
		if (word("true")) return Value::of(true);
		if (word("false")) return Value::of(false);
		if (word("null")) return Value();
		return number();
	}
	Value object() {
		Value v = Value::object();
		i++;
		space();
		if (i < s.size() && s[i] == '}') {
			i++;
			return v;
		}
		while (true) {
			space();
			if (i >= s.size() || s[i] != '"') fail("expected a key");
			std::string key = string();
			space();
			if (i >= s.size() || s[i] != ':') fail("expected ':'");
			i++;
			v.fields->emplace_back(key, value());
			space();
			if (i < s.size() && s[i] == ',') {
				i++;
				continue;
			}
			if (i < s.size() && s[i] == '}') {
				i++;
				return v;
			}
			fail("expected ',' or '}'");
		}
	}
	Value array() {
		Value v = Value::array();
		i++;
		space();
		if (i < s.size() && s[i] == ']') {
			i++;
			return v;
		}
		while (true) {
			v.items->push_back(value());
			space();
			if (i < s.size() && s[i] == ',') {
				i++;
				continue;
			}
			if (i < s.size() && s[i] == ']') {
				i++;
				return v;
			}
			fail("expected ',' or ']'");
		}
	}
	static void utf8(std::string& out, uint32_t cp) {
		if (cp < 0x80) {
			out += char(cp);
		} else if (cp < 0x800) {
			out += char(0xC0 | (cp >> 6));
			out += char(0x80 | (cp & 0x3F));
		} else if (cp < 0x10000) {
			out += char(0xE0 | (cp >> 12));
			out += char(0x80 | ((cp >> 6) & 0x3F));
			out += char(0x80 | (cp & 0x3F));
		} else {
			out += char(0xF0 | (cp >> 18));
			out += char(0x80 | ((cp >> 12) & 0x3F));
			out += char(0x80 | ((cp >> 6) & 0x3F));
			out += char(0x80 | (cp & 0x3F));
		}
	}
	uint32_t hex4() {
		if (i + 4 > s.size()) fail("short \\u escape");
		uint32_t cp = 0;
		for (int k = 0; k < 4; k++) {
			char h = s[i++];
			cp <<= 4;
			if (h >= '0' && h <= '9') cp |= uint32_t(h - '0');
			else if (h >= 'a' && h <= 'f') cp |= uint32_t(h - 'a' + 10);
			else if (h >= 'A' && h <= 'F') cp |= uint32_t(h - 'A' + 10);
			else fail("bad \\u escape");
		}
		return cp;
	}
	std::string string() {
		std::string out;
		i++;
		while (i < s.size() && s[i] != '"') {
			char c = s[i++];
			if (c != '\\') {
				out += c;
				continue;
			}
			if (i >= s.size()) fail("bad escape");
			char e = s[i++];
			switch (e) {
				case '"': out += '"'; break;
				case '\\': out += '\\'; break;
				case '/': out += '/'; break;
				case 'b': out += '\b'; break;
				case 'f': out += '\f'; break;
				case 'n': out += '\n'; break;
				case 'r': out += '\r'; break;
				case 't': out += '\t'; break;
				case 'u': {
					uint32_t cp = hex4();
					if (cp >= 0xD800 && cp < 0xDC00 && word("\\u")) cp = 0x10000 + ((cp - 0xD800) << 10) + (hex4() - 0xDC00);
					utf8(out, cp);
					break;
				}
				default: fail("bad escape");
			}
		}
		if (i >= s.size()) fail("unterminated string");
		i++;
		return out;
	}
	Value number() {
		size_t start = i;
		while (i < s.size() && (std::string("+-0123456789.eE").find(s[i]) != std::string::npos)) i++;
		if (start == i) fail("unexpected character");
		double n = 0;
		auto [end, error] = std::from_chars(s.data() + start, s.data() + i, n);
		if (error != std::errc() || end != s.data() + i) fail("bad number");
		return Value::of(n);
	}
};

inline Value parse(const std::string& text) { return Parser(text).parse(); }

// LEARN: std::to_chars with no precision writes the shortest text that reads back as the same double, which is the
// rule JavaScript's Number.prototype.toString follows; a whole number has no fraction to print.
inline void write_number(std::string& out, double n) {
	if (!std::isfinite(n)) throw std::runtime_error("a bolt's number is not finite");
	if (n == 0) {
		out += "0";
		return;
	}
	char buffer[64];
	if (std::floor(n) == n && std::fabs(n) < 1e21) {
		auto [end, error] = std::to_chars(buffer, buffer + sizeof buffer, static_cast<long long>(n));
		out.append(buffer, end);
		return;
	}
	auto [end, error] = std::to_chars(buffer, buffer + sizeof buffer, n);
	out.append(buffer, end);
}

inline void write_string(std::string& out, const std::string& s) {
	out += '"';
	for (unsigned char c : s) {
		switch (c) {
			case '"': out += "\\\""; break;
			case '\\': out += "\\\\"; break;
			case '\n': out += "\\n"; break;
			case '\r': out += "\\r"; break;
			case '\t': out += "\\t"; break;
			default:
				if (c < 0x20) {
					char buffer[8];
					std::snprintf(buffer, sizeof buffer, "\\u%04x", c);
					out += buffer;
				} else {
					out += char(c);
				}
		}
	}
	out += '"';
}

inline void write(std::string& out, const Value& v) {
	switch (v.kind) {
		case Value::Kind::null: out += "null"; break;
		case Value::Kind::boolean: out += v.boolean ? "true" : "false"; break;
		case Value::Kind::number: write_number(out, v.number); break;
		case Value::Kind::string: write_string(out, v.text); break;
		case Value::Kind::array: {
			out += '[';
			bool first = true;
			for (const auto& item : *v.items) {
				if (!first) out += ',';
				first = false;
				write(out, item);
			}
			out += ']';
			break;
		}
		case Value::Kind::object: {
			out += '{';
			bool first = true;
			for (const auto& [key, value] : *v.fields) {
				if (!first) out += ',';
				first = false;
				write_string(out, key);
				out += ':';
				write(out, value);
			}
			out += '}';
			break;
		}
	}
}

inline std::string dump(const Value& v) {
	std::string out;
	write(out, v);
	return out;
}

}  // namespace rootward::json
