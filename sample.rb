require "pitacc"
require "pitacc/ll1"

class MyParser < PitaCC::Parser
    set_engine :LL1

    uppercase_is_nonterminal
    # lowercase_is_terminal

    def parse lex
        @buf = []
        super
        return @buf
    end

    rules {
        rule :EXPR,         :TERM, :"EXPR'"

        rule :"EXPR'",      :OP1, :EXPR do|op, e|
            @buf << op
        end

        rule :OP1,          :+
        rule :OP1,          :-

        rule :"EXPR'"  # ε


        rule :TERM,         :FACTOR, :"TERM'"

        rule :"TERM'",      :OP2, :TERM do|op, t|
            @buf << op
        end

        rule :OP2,          :*
        rule :OP2,          :/

        rule :"TERM'"  # ε

        rule :FACTOR,       :num do|n|
            @buf << n
        end

        rule :FACTOR,       :"(", :EXPR, :")"
    }
end

class Token
    attr_accessor :sym, :val
end

class Lex
    def initialize
        @buf = "2 * (1 - 6) / (3 + 5)"
        @current = nil
    end

    def peek
        if @current then
            return @current
        end
        next_token
        return @current
    end

    def get
        if @current then
            tmp = @current
            @current = nil
            return tmp
        end
        next_token
        tmp = @current
        @current = nil
        return tmp
    end

    def next_token
        token = Token.new
        @current = token

        if m = /\A\s+/.match(@buf) then
            @buf[0, m[0].length] = ""
        end

        case
        when m = /\A\z/.match(@buf) then
            @buf[0, m[0].length] = ""
            token.sym = "$"
        when m = /\A\(/.match(@buf) then
            @buf[0, m[0].length] = ""
            token.sym = :"("
        when m = /\A\)/.match(@buf) then
            @buf[0, m[0].length] = ""
            token.sym = :")"
        when m = /\A\+/.match(@buf) then
            @buf[0, m[0].length] = ""
            token.sym = :+
        when m = /\A\-/.match(@buf) then
            @buf[0, m[0].length] = ""
            token.sym = :-
        when m = /\A\*/.match(@buf) then
            @buf[0, m[0].length] = ""
            token.sym = :*
        when m = /\A\//.match(@buf) then
            @buf[0, m[0].length] = ""
            token.sym = :/
        when m = /\A\d+/.match(@buf) then
            @buf[0, m[0].length] = ""
            token.sym = :num
            token.val = m[0].to_i
        else
            raise "lex error"
        end
    end
end

parser = MyParser.new
p parser.parse Lex.new
