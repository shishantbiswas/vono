# Request Validator
Schema-based request validation for JSON body, query parameters, path parameters, and headers.

```v
import vono

fn main() {
    mut app := vono.Vono.new()

    // Validate JSON body
    app.post('/users',
        vono.validate_json(vono.v_object({
            'name':  vono.v_string().required().min(2).max(50)
            'email': vono.v_string().required().pattern(r'^[\w\.-]+@[\w\.-]+\.\w+$')
            'age':   vono.v_int().min(0).max(150)
        })),
        fn (mut c vono.Context) http.Response {
            data := vono.get_validated_data(c)
            name := data['name'] or { '' }
            email := data['email'] or { '' }
            return c.json('{"message": "User created", "name": "${name}", "email": "${email}"}')
        }
    )

    // Validate query parameters
    app.get('/search',
        vono.validate_query(vono.v_object({
            'q':    vono.v_string().required().min(1)
            'page': vono.v_int().min(1)
            'size': vono.v_int().min(1).max(100)
        })),
        fn (mut c vono.Context) http.Response {
            q := vono.get_validated_field(c, 'q') or { '' }
            page := vono.get_validated_field(c, 'page') or { '1' }
            return c.json('{"query": "${q}", "page": ${page}}')
        }
    )

    // Validate path parameters
    app.get('/users/:id',
        vono.validate_params(vono.v_object({
            'id': vono.v_int().required().min(1)
        })),
        fn (mut c vono.Context) http.Response {
            id := vono.get_validated_field(c, 'id') or { '0' }
            return c.json('{"user_id": ${id}}')
        }
    )

    // Validate headers
    app.use('/api/*', vono.validate_headers(vono.v_object({
        'X-API-Key': vono.v_string().required()
    })))

    app.listen(':3000')
}
```